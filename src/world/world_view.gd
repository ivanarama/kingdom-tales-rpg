class_name WorldView
extends Control

signal cell_clicked(cell: Vector2i)
signal cancel_movement_requested

const TILE_SIZE: float = 64.0
const MAP_COLS: int = 32
const MAP_ROWS: int = 22

# Textures
var tex_grass: Array[Texture2D] = []
var tex_dirt: Texture2D
var tex_forest: Texture2D
var tex_hero: Texture2D
var tex_hero_side: Texture2D
var tex_hero_up: Texture2D
var tex_hero_down: Texture2D

var icons: Dictionary = {}
var creature_tokens: Dictionary = {}

# Map data
var road_cells: Array[Vector2i] = []
var forest_cells: Array[Vector2i] = []
var objects: Dictionary = {} # cell -> {type: "chest"|"mill"|..., id: "...", name: "..."}
var revealed_cells: Dictionary = {}

# Hero state
var hero_cell: Vector2i = Vector2i(4, 11)
var hero_pixel_pos: Vector2 = Vector2.ZERO
var is_moving: bool = false
var facing_right: bool = true
var facing_dir: Vector2i = Vector2i(1, 0)
var move_dir: Vector2i = Vector2i.ZERO
var walk_anim_timer: float = 0.0
var anim_timer: float = 0.0
var objective_cell: Vector2i = Vector2i(-99, -99) # цель квеста (задаёт world_map)
var movement_start_time: int = 0

# Path preview and locked planned route (HoMM3 2-click movement)
var preview_path: Array[Vector2i] = []
var planned_path: Array[Vector2i] = []
var planned_destination: Vector2i = Vector2i(-1, -1)
var hovered_cell: Vector2i = Vector2i(-1, -1)

func set_planned_route(path: Array[Vector2i], destination: Vector2i) -> void:
	planned_path = path
	planned_destination = destination
	preview_path.clear()
	queue_redraw()

func clear_planned_route() -> void:
	planned_path.clear()
	planned_destination = Vector2i(-1, -1)
	queue_redraw()

func remove_object_by_id(obj_id: String) -> void:
	for c in objects.keys():
		if objects[c].get("id", "") == obj_id:
			objects.erase(c)
			queue_redraw()
			break

func remove_object_at(cell: Vector2i) -> void:
	if objects.has(cell):
		objects.erase(cell)
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_COLS * TILE_SIZE, MAP_ROWS * TILE_SIZE)
	_load_textures()
	_generate_map_layout()
	
	# Restore persistent location & fog from GameState
	hero_cell = GameState.hero_cell
	hero_pixel_pos = cell_to_pixel(hero_cell)
	if GameState.revealed_cells.size() > 0:
		revealed_cells = GameState.revealed_cells.duplicate()
	_reveal_fog(hero_cell, 5)

func _load_textures() -> void:
	for i in range(4):
		var p = "res://assets/art/world/tile_grass_%d.png" % i
		if ResourceLoader.exists(p):
			tex_grass.append(load(p))
	tex_dirt = load("res://assets/art/world/tile_dirt.png")
	tex_forest = load("res://assets/art/world/tile_forest.png")
	tex_hero = load("res://assets/art/world/hero.png")
	tex_hero_side = load("res://assets/art/world/hero_side.png") if ResourceLoader.exists("res://assets/art/world/hero_side.png") else tex_hero
	tex_hero_up = load("res://assets/art/world/hero_up.png") if ResourceLoader.exists("res://assets/art/world/hero_up.png") else tex_hero
	tex_hero_down = load("res://assets/art/world/hero_down.png") if ResourceLoader.exists("res://assets/art/world/hero_down.png") else tex_hero
	
	icons["chest"] = load("res://assets/art/world/icon_pickup.png")
	icons["mill"] = load("res://assets/art/world/icon_camp.png")
	icons["fountain"] = load("res://assets/art/world/icon_artifact.png")
	icons["fairy_dwelling"] = load("res://assets/art/world/icon_dialogue.png")
	icons["encounter"] = load("res://assets/art/world/icon_encounter.png")
	icons["bandit_boss"] = load("res://assets/art/world/icon_encounter.png")
	icons["forester"] = load("res://assets/art/world/icon_quest.png")
	icons["gate"] = load("res://assets/art/world/icon_exit.png")
	icons["signpost"] = load("res://assets/art/world/icon_dialogue.png")
	icons["obelisk"] = load("res://assets/art/world/icon_artifact.png")
	icons["merchant"] = load("res://assets/art/world/icon_artifact.png")
	icons["fairy_shrine"] = load("res://assets/art/world/icon_quest.png")
	
	# Chapter 2 & 3 aliases
	icons["witch_hut"] = icons["forester"]
	icons["druid_camp"] = icons["fairy_dwelling"]
	icons["upgrade_altar"] = icons["obelisk"]
	icons["bone_gate"] = icons["gate"]
	icons["crypt"] = icons["mill"]
	icons["lich_boss"] = icons["bandit_boss"]
	icons["druid_altar"] = icons["fairy_shrine"]
	icons["dragon_gate"] = icons["gate"]
	icons["dragon_boss"] = icons["bandit_boss"]
	icons["dragon_altar"] = icons["fairy_shrine"]
	icons["griffin_roost"] = icons["fairy_dwelling"]
	icons["forge"] = icons["mill"]
	
	# Load dedicated creature & boss miniatures for adventure map
	var token_map = {
		"wolf": "res://assets/art/ui/tokens/token_unit_wolf.png",
		"goblin": "res://assets/art/ui/tokens/token_unit_goblin.png",
		"treant": "res://assets/art/ui/tokens/token_unit_treant.png",
		"fairy_archer": "res://assets/art/ui/tokens/token_unit_fairy_archer.png",
		"skeleton_archer": "res://assets/art/ui/tokens/token_unit_skeleton_archer.png",
		"swamp_zombie": "res://assets/art/ui/tokens/token_unit_swamp_zombie.png",
		"griffin": "res://assets/art/ui/tokens/token_unit_griffin.png",
		"bandit_boss": "res://assets/art/ui/tokens/token_boss_bandit.png",
		"lich_boss": "res://assets/art/ui/tokens/token_boss_lich.png",
		"dragon_boss": "res://assets/art/ui/tokens/token_boss_dragon.png"
	}
	for k in token_map.keys():
		var p = token_map[k]
		if ResourceLoader.exists(p):
			creature_tokens[k] = load(p)

func get_object_texture(obj: Dictionary) -> Texture2D:
	var type = obj.get("type", "")
	var id = obj.get("id", "")
	
	if type == "bandit_boss" or id == "bandit_boss":
		return creature_tokens.get("bandit_boss", icons.get("bandit_boss"))
	if type == "lich_boss" or id == "lich_boss":
		return creature_tokens.get("lich_boss", icons.get("lich_boss"))
	if type == "dragon_boss" or id == "dragon_boss":
		return creature_tokens.get("dragon_boss", icons.get("dragon_boss"))
		
	if type == "encounter":
		match id:
			"patrol_wolves":
				return creature_tokens.get("wolf", icons.get("encounter"))
			"patrol_goblins", "patrol_forester", "patrol_1", "patrol_rogues", "patrol_2":
				return creature_tokens.get("goblin", icons.get("encounter"))
			"patrol_grove", "patrol_obelisk", "dragon_patrol_caldera":
				return creature_tokens.get("treant", icons.get("encounter"))
			"swamp_patrol_road", "swamp_patrol_east", "swamp_patrol", "patrol_swamp":
				return creature_tokens.get("swamp_zombie", icons.get("encounter"))
			"swamp_patrol_fens", "swamp_patrol_gate", "dragon_patrol_gate":
				return creature_tokens.get("skeleton_archer", icons.get("encounter"))
			"swamp_patrol_ruins":
				return creature_tokens.get("lich_boss", icons.get("encounter"))
			"dragon_patrol_pass", "dragon_patrol_citadel", "dragon_patrol":
				return creature_tokens.get("griffin", icons.get("encounter"))
			_:
				if GameState.current_chapter == 2:
					return creature_tokens.get("swamp_zombie", icons.get("encounter"))
				elif GameState.current_chapter == 3:
					return creature_tokens.get("dragon_boss", icons.get("encounter"))
				else:
					return creature_tokens.get("goblin", icons.get("encounter"))
					
	return icons.get(type, null)

func _generate_map_layout() -> void:
	forest_cells.clear()
	road_cells.clear()
	objects.clear()
	
	match GameState.current_chapter:
		2:
			_generate_chapter2_layout()
		3:
			_generate_chapter3_layout()
		_:
			_generate_chapter1_layout()

func _generate_chapter1_layout() -> void:
	# 1. Outer dense perimeter
	for x in range(MAP_COLS):
		forest_cells.append(Vector2i(x, 0))
		forest_cells.append(Vector2i(x, MAP_ROWS - 1))
	for y in range(MAP_ROWS):
		forest_cells.append(Vector2i(0, y))
		forest_cells.append(Vector2i(MAP_COLS - 1, y))
		
	# 2. Central mountain / thick forest ridge separating West and East (x = 14)
	for y in range(1, MAP_ROWS - 1):
		if y != 11:
			forest_cells.append(Vector2i(14, y))
			forest_cells.append(Vector2i(15, y))
			
	# West forest clumps
	for x in range(2, 6):
		for y in range(13, 17):
			forest_cells.append(Vector2i(x, y))
	for x in range(9, 13):
		for y in range(14, 18):
			forest_cells.append(Vector2i(x, y))
	for x in range(1, 4):
		for y in range(5, 8):
			forest_cells.append(Vector2i(x, y))
			
	# East forest clumps
	for x in range(17, 21):
		for y in range(6, 10):
			forest_cells.append(Vector2i(x, y))
	for x in range(18, 22):
		for y in range(13, 17):
			forest_cells.append(Vector2i(x, y))
	for x in range(24, 27):
		for y in range(13, 16):
			forest_cells.append(Vector2i(x, y))
	for x in range(20, 25):
		for y in range(1, 4):
			forest_cells.append(Vector2i(x, y))

	# 3. Roads
	for x in range(3, 15):
		road_cells.append(Vector2i(x, 11))
	for y in range(4, 12):
		road_cells.append(Vector2i(7, y))
	for x in range(4, 11):
		road_cells.append(Vector2i(x, 4))
	for y in range(11, 19):
		road_cells.append(Vector2i(7, y))
	for x in range(14, 29):
		road_cells.append(Vector2i(x, 11))
	for y in range(11, 19):
		road_cells.append(Vector2i(22, y))
	for x in range(22, 28):
		road_cells.append(Vector2i(x, 18))
	for y in range(4, 12):
		road_cells.append(Vector2i(22, y))
	for x in range(22, 28):
		road_cells.append(Vector2i(x, 4))

	# 4. Interactive Landmarks & Objects
	objects[Vector2i(5, 11)] = {"type": "signpost", "name": "Путевой Камень", "id": "sign_start"}
	objects[Vector2i(4, 4)] = {"type": "fountain", "name": "Священный Источник Маны", "id": "mana_fountain"}
	objects[Vector2i(10, 4)] = {"type": "mill", "name": "Старая Мельница", "id": "watermill"}
	objects[Vector2i(10, 8)] = {"type": "fairy_dwelling", "name": "Роща Лесных Лучниц", "id": "fairy_camp"}
	objects[Vector2i(7, 18)] = {"type": "forester", "name": "Хижина Лесника", "id": "forester_hut"}
	objects[Vector2i(14, 11)] = {"type": "gate", "name": "Железные Врата Ущелья", "id": "iron_gate"}
	objects[Vector2i(27, 18)] = {"type": "obelisk", "name": "Древний Обелиск", "id": "ancient_obelisk"}
	objects[Vector2i(27, 4)] = {"type": "fairy_shrine", "name": "Роща Королевы Фей", "id": "fairy_shrine"}

	# Chapter 1 Chests
	if not GameState.flags.get("chest_start", false):
		objects[Vector2i(4, 9)] = {"type": "chest", "name": "Сундук в траве", "id": "chest_start", "cell": Vector2i(4, 9)}
	if not GameState.flags.get("chest_north", false):
		objects[Vector2i(11, 3)] = {"type": "chest", "name": "Сундук у мельницы", "id": "chest_north", "cell": Vector2i(11, 3)}
	if not GameState.flags.get("chest_grove", false):
		objects[Vector2i(11, 13)] = {"type": "chest", "name": "Тайник в чащобе", "id": "chest_grove", "cell": Vector2i(11, 13)}
	if not GameState.flags.get("chest_hoard", false):
		objects[Vector2i(25, 18)] = {"type": "chest", "name": "Сокровище Ущелья", "id": "chest_hoard", "cell": Vector2i(25, 18)}

	# Chapter 1 Tactical Encounters (Guarding locations & paths)
	if not GameState.flags.get("patrol_wolves", false):
		objects[Vector2i(8, 4)] = {"type": "encounter", "name": "Стая Волков (Мельница)", "id": "patrol_wolves"}
	if not GameState.flags.get("patrol_goblins", false):
		objects[Vector2i(4, 8)] = {"type": "encounter", "name": "Шайка Гоблинов (Сундук)", "id": "patrol_goblins"}
	if not GameState.flags.get("patrol_forester", false):
		objects[Vector2i(7, 14)] = {"type": "encounter", "name": "Засада Разбойников (Тракт)", "id": "patrol_forester"}
	if not GameState.flags.get("patrol_grove", false):
		objects[Vector2i(10, 13)] = {"type": "encounter", "name": "Страж Рощи (Древень)", "id": "patrol_grove"}
	if not GameState.flags.get("patrol_1", false):
		objects[Vector2i(18, 11)] = {"type": "encounter", "name": "Авангард Разбойников", "id": "patrol_1"}
	if not GameState.flags.get("patrol_rogues", false):
		objects[Vector2i(22, 7)] = {"type": "encounter", "name": "Дозор Стрелков", "id": "patrol_rogues"}
	if not GameState.flags.get("patrol_obelisk", false):
		objects[Vector2i(24, 16)] = {"type": "encounter", "name": "Стража Обелиска", "id": "patrol_obelisk"}
	if not GameState.flags.get("bandit_boss", false):
		objects[Vector2i(28, 11)] = {"type": "bandit_boss", "name": "Логово Атамана", "id": "bandit_boss"}

func _generate_chapter2_layout() -> void:
	# 1. Outer swamp border
	for x in range(MAP_COLS):
		forest_cells.append(Vector2i(x, 0))
		forest_cells.append(Vector2i(x, MAP_ROWS - 1))
	for y in range(MAP_ROWS):
		forest_cells.append(Vector2i(0, y))
		forest_cells.append(Vector2i(MAP_COLS - 1, y))
		
	# 2. Impassable swamp bogs and deep mires (organic marsh clusters)
	for y in range(1, MAP_ROWS - 1):
		if y != 11:
			forest_cells.append(Vector2i(14, y))
			forest_cells.append(Vector2i(15, y))
			
	for x in range(1, 5):
		for y in range(1, 4):
			forest_cells.append(Vector2i(x, y))
	for x in range(8, 13):
		for y in range(1, 4):
			forest_cells.append(Vector2i(x, y))
	for x in range(1, 5):
		for y in range(7, 10):
			forest_cells.append(Vector2i(x, y))
	for x in range(8, 12):
		for y in range(8, 11):
			forest_cells.append(Vector2i(x, y))
	for x in range(1, 5):
		for y in range(13, 16):
			forest_cells.append(Vector2i(x, y))
	for x in range(8, 13):
		for y in range(13, 16):
			forest_cells.append(Vector2i(x, y))

	for x in range(17, 21):
		for y in range(7, 10):
			forest_cells.append(Vector2i(x, y))
	for x in range(17, 21):
		for y in range(13, 16):
			forest_cells.append(Vector2i(x, y))
	for x in range(23, 27):
		for y in range(7, 10):
			forest_cells.append(Vector2i(x, y))
	for x in range(23, 27):
		for y in range(13, 16):
			forest_cells.append(Vector2i(x, y))
	for x in range(19, 25):
		for y in range(1, 4):
			forest_cells.append(Vector2i(x, y))

	# 3. Wooden boardwalk causeways through the marsh
	for x in range(2, 15):
		road_cells.append(Vector2i(x, 11))
	for y in range(4, 12):
		road_cells.append(Vector2i(6, y))
	for x in range(3, 12):
		road_cells.append(Vector2i(x, 4))
	for y in range(11, 18):
		road_cells.append(Vector2i(6, y))
	for x in range(6, 12):
		road_cells.append(Vector2i(x, 17))

	for x in range(14, 29):
		road_cells.append(Vector2i(x, 11))
	for y in range(4, 12):
		road_cells.append(Vector2i(21, y))
	for x in range(21, 28):
		road_cells.append(Vector2i(x, 4))
	for y in range(11, 18):
		road_cells.append(Vector2i(21, y))
	for x in range(21, 27):
		road_cells.append(Vector2i(x, 17))

	# 4. Landmarks in Chapter 2
	objects[Vector2i(5, 11)] = {"type": "signpost", "name": "Указатель Проклятых Топей", "id": "sign_swamp"}
	objects[Vector2i(4, 4)] = {"type": "fountain", "name": "Священный Источник Жизни", "id": "fountain_swamp"}
	objects[Vector2i(10, 4)] = {"type": "crypt", "name": "Затонувший Склеп", "id": "sunken_crypt"}
	objects[Vector2i(10, 7)] = {"type": "druid_camp", "name": "Круг Болотных Друидов", "id": "druid_camp"}
	objects[Vector2i(6, 17)] = {"type": "witch_hut", "name": "Хижина Болотной Ведьмы", "id": "witch_hut"}
	objects[Vector2i(10, 11)] = {"type": "upgrade_altar", "name": "Алтарь Преображения Войск", "id": "upgrade_altar"}
	objects[Vector2i(14, 11)] = {"type": "bone_gate", "name": "Костяные Врата Некрополя", "id": "bone_gate"}
	objects[Vector2i(27, 4)] = {"type": "druid_altar", "name": "Алтарь Очищения Топей", "id": "druid_altar"}
	objects[Vector2i(26, 17)] = {"type": "obelisk", "name": "Изумрудный Обелиск", "id": "obelisk_swamp"}
	objects[Vector2i(28, 11)] = {"type": "lich_boss", "name": "Цитадель Древнего Лича", "id": "lich_boss"}

	# Chapter 2 Chests
	if not GameState.flags.get("chest_swamp_1", false):
		objects[Vector2i(10, 17)] = {"type": "chest", "name": "Сундук в мху", "id": "chest_swamp_1", "cell": Vector2i(10, 17)}
	if not GameState.flags.get("chest_swamp_north", false):
		objects[Vector2i(7, 4)] = {"type": "chest", "name": "Сундук утопленника", "id": "chest_swamp_north", "cell": Vector2i(7, 4)}
	if not GameState.flags.get("chest_swamp_2", false):
		objects[Vector2i(25, 17)] = {"type": "chest", "name": "Сокровище Склепа", "id": "chest_swamp_2", "cell": Vector2i(25, 17)}

	# Chapter 2 Tactical Encounters
	if not GameState.flags.get("swamp_patrol_road", false):
		objects[Vector2i(6, 8)] = {"type": "encounter", "name": "Болотные Зомби (Северная гать)", "id": "swamp_patrol_road"}
	if not GameState.flags.get("swamp_patrol_fens", false):
		objects[Vector2i(6, 14)] = {"type": "encounter", "name": "Скелеты Топей (Южный тракт)", "id": "swamp_patrol_fens"}
	if not GameState.flags.get("swamp_patrol_gate", false):
		objects[Vector2i(13, 11)] = {"type": "encounter", "name": "Костяная Стража Врат", "id": "swamp_patrol_gate"}
	if not GameState.flags.get("swamp_patrol_east", false):
		objects[Vector2i(21, 8)] = {"type": "encounter", "name": "Легион Смерти (Северный дозор)", "id": "swamp_patrol_east"}
	if not GameState.flags.get("swamp_patrol_ruins", false):
		objects[Vector2i(21, 14)] = {"type": "encounter", "name": "Стражи Гробниц (Южный дозор)", "id": "swamp_patrol_ruins"}

func _generate_chapter3_layout() -> void:
	# 1. Outer volcanic perimeter
	for x in range(MAP_COLS):
		forest_cells.append(Vector2i(x, 0))
		forest_cells.append(Vector2i(x, MAP_ROWS - 1))
	for y in range(MAP_ROWS):
		forest_cells.append(Vector2i(0, y))
		forest_cells.append(Vector2i(MAP_COLS - 1, y))
		
	# 2. Volcanic mountain ridge
	for y in range(1, MAP_ROWS - 1):
		if y != 11:
			forest_cells.append(Vector2i(14, y))
			forest_cells.append(Vector2i(15, y))
			
	for x in range(2, 6):
		for y in range(5, 9):
			forest_cells.append(Vector2i(x, y))
	for x in range(8, 12):
		for y in range(12, 15):
			forest_cells.append(Vector2i(x, y))
	for x in range(17, 21):
		for y in range(13, 17):
			forest_cells.append(Vector2i(x, y))
	for x in range(23, 27):
		for y in range(3, 7):
			forest_cells.append(Vector2i(x, y))

	# 3. Mountain passes
	for x in range(3, 15):
		road_cells.append(Vector2i(x, 16))
	for y in range(11, 17):
		road_cells.append(Vector2i(10, y))
	for x in range(10, 15):
		road_cells.append(Vector2i(x, 11))
	for y in range(4, 12):
		road_cells.append(Vector2i(5, y))
	for x in range(5, 11):
		road_cells.append(Vector2i(x, 4))
	for x in range(14, 29):
		road_cells.append(Vector2i(x, 11))
	for y in range(4, 12):
		road_cells.append(Vector2i(22, y))
	for x in range(22, 28):
		road_cells.append(Vector2i(x, 4))
	for y in range(11, 19):
		road_cells.append(Vector2i(22, y))
	for x in range(22, 28):
		road_cells.append(Vector2i(x, 18))

	# 4. Landmarks in Chapter 3
	objects[Vector2i(6, 16)] = {"type": "signpost", "name": "Указатель Огненного Перевала", "id": "sign_volcano"}
	objects[Vector2i(10, 4)] = {"type": "forge", "name": "Кузница Горных Владык", "id": "dwarf_forge"}
	objects[Vector2i(5, 4)] = {"type": "fountain", "name": "Магматический Источник", "id": "fountain_volcano"}
	objects[Vector2i(8, 16)] = {"type": "griffin_roost", "name": "Гнездовье Королевских Грифонов", "id": "griffin_nest"}
	objects[Vector2i(10, 11)] = {"type": "upgrade_altar", "name": "Огненный Алтарь Силы", "id": "upgrade_altar_volcano"}
	objects[Vector2i(14, 11)] = {"type": "dragon_gate", "name": "Огненные Врата Ущелья", "id": "dragon_gate"}
	objects[Vector2i(27, 4)] = {"type": "dragon_altar", "name": "Королевская Цитадель Победы", "id": "royal_citadel"}
	objects[Vector2i(22, 6)] = {"type": "obelisk", "name": "Рунический Столп Огня", "id": "obelisk_volcano"}
	objects[Vector2i(28, 11)] = {"type": "dragon_boss", "name": "Пик Красного Дракона", "id": "dragon_boss"}

	# Chapter 3 Chests
	if not GameState.flags.get("chest_volcano_1", false):
		objects[Vector2i(4, 13)] = {"type": "chest", "name": "Сундук в пепле", "id": "chest_volcano_1", "cell": Vector2i(4, 13)}
	if not GameState.flags.get("chest_volcano_2", false):
		objects[Vector2i(25, 18)] = {"type": "chest", "name": "Клад Дракона", "id": "chest_volcano_2", "cell": Vector2i(25, 18)}

	# Chapter 3 Tactical Encounters
	if not GameState.flags.get("dragon_patrol_pass", false):
		objects[Vector2i(10, 13)] = {"type": "encounter", "name": "Огненный Дозор (Перевал)", "id": "dragon_patrol_pass"}
	if not GameState.flags.get("dragon_patrol_gate", false):
		objects[Vector2i(13, 11)] = {"type": "encounter", "name": "Стража Врат", "id": "dragon_patrol_gate"}
	if not GameState.flags.get("dragon_patrol_caldera", false):
		objects[Vector2i(22, 8)] = {"type": "encounter", "name": "Драконьи Слуги (Кратер)", "id": "dragon_patrol_caldera"}
	if not GameState.flags.get("dragon_patrol_citadel", false):
		objects[Vector2i(22, 15)] = {"type": "encounter", "name": "Лавовые Хищники (Плато)", "id": "dragon_patrol_citadel"}

func cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func pixel_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE_SIZE)), int(floor(pos.y / TILE_SIZE)))

func is_passable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= MAP_COLS or cell.y < 0 or cell.y >= MAP_ROWS:
		return false
	if forest_cells.has(cell):
		return false
	return true

## Объект, сквозь который нельзя пройти: живой патруль или босс, запертые врата.
## Герой останавливается перед ним и взаимодействует с соседней клетки.
static func is_blocking_object(obj: Dictionary) -> bool:
	var id: String = obj.get("id", "")
	match obj.get("type", ""):
		"encounter", "bandit_boss", "lich_boss", "dragon_boss":
			return not GameState.flags.get(id, false)
		"gate":
			return not GameState.flags.get("iron_gate_opened", false)
		"bone_gate":
			return not GameState.flags.get("bone_gate_opened", false)
		"dragon_gate":
			return not GameState.flags.get("dragon_gate_opened", false)
	return false

## Непроходимые клетки для прокладки маршрута к target: лес и блокирующие объекты.
## Сама цель в список не входит — к патрулю или вратам маршрут строится, но обрывается перед ними.
func get_path_obstacles(target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = forest_cells.duplicate()
	for c in objects.keys():
		if c != target and is_blocking_object(objects[c]):
			result.append(c)
	return result

func _reveal_fog(center: Vector2i, radius: int) -> void:
	var bounds := Rect2i(0, 0, MAP_COLS, MAP_ROWS)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var c := center + Vector2i(dx, dy)
				if bounds.has_point(c):
					revealed_cells[c] = true
	GameState.revealed_cells = revealed_cells

func _gui_input(event: InputEvent) -> void:
	var cur_scale = scale if scale.x > 0.01 else Vector2.ONE
	if event is InputEventMouseMotion:
		var pos = event.position / cur_scale
		var c = pixel_to_cell(pos)
		if c != hovered_cell:
			hovered_cell = c
			_update_preview_path()
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if is_moving:
			if not event.double_click:
				cancel_movement_requested.emit()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			var pos = event.position / cur_scale
			var clicked = pixel_to_cell(pos)
			cell_clicked.emit(clicked)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if planned_path.size() > 0:
				clear_planned_route()
				SoundManager.play_sfx("click")

func _update_preview_path() -> void:
	if is_moving or planned_path.size() > 0 or not is_passable(hovered_cell) or hovered_cell == hero_cell:
		preview_path.clear()
		return
	var bounds = Rect2i(0, 0, MAP_COLS, MAP_ROWS)
	var has_pf = GameState.has_skill("pathfinding") if GameState.has_method("has_skill") else false
	preview_path = WorldNavigator.find_path(hero_cell, hovered_cell, get_path_obstacles(hovered_cell), bounds, road_cells, has_pf)

var _reduced_accum: float = 0.0

func _process(delta: float) -> void:
	anim_timer += delta
	if is_moving:
		walk_anim_timer += delta * 12.0
	# Упрощённые анимации: живая карта обновляется 10 раз в секунду вместо каждого кадра
	if SettingsManager.reduced_animations and not is_moving:
		_reduced_accum += delta
		if _reduced_accum >= 0.1:
			_reduced_accum = 0.0
			queue_redraw()
	else:
		queue_redraw()

func _draw() -> void:
	# 1. Base Terrain by Chapter Biome
	for y in range(MAP_ROWS):
		for x in range(MAP_COLS):
			var c = Vector2i(x, y)
			var r = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not revealed_cells.has(c):
				draw_rect(r, Color(0.02, 0.03, 0.05, 1.0))
				continue
			if GameState.current_chapter == 2:
				_draw_swamp_cell(c, r)
			elif GameState.current_chapter == 3:
				_draw_volcano_cell(c, r)
			else:
				_draw_forest_cell(c, r)
					
	# Subtle grid lines (authentic HoMM style)
	for y in range(MAP_ROWS + 1):
		draw_line(Vector2(0, y * TILE_SIZE), Vector2(MAP_COLS * TILE_SIZE, y * TILE_SIZE), Color(0, 0, 0, 0.12), 1.0)
	for x in range(MAP_COLS + 1):
		draw_line(Vector2(x * TILE_SIZE, 0), Vector2(x * TILE_SIZE, MAP_ROWS * TILE_SIZE), Color(0, 0, 0, 0.12), 1.0)

	# Atmospheric Biome Overlays
	if GameState.current_chapter == 2:
		# Ambient drifting mist over the swamp
		var mist_col = Color(0.68, 0.80, 0.72, 0.08)
		for mi in range(6):
			var m_y = float(mi * 240) + sin(anim_timer * 0.3 + float(mi)) * 45.0
			var m_x = fmod(anim_timer * 14.0 + float(mi * 320), float(MAP_COLS * TILE_SIZE + 500.0)) - 250.0
			draw_circle(Vector2(m_x, m_y), 170.0, mist_col)
			draw_circle(Vector2(m_x + 130.0, m_y + 35.0), 150.0, mist_col)
	elif GameState.current_chapter == 3:
		# Ambient rising embers over the volcanic wasteland
		for ei in range(12):
			var et = fmod(anim_timer * 1.1 + float(ei * 0.55), 1.0)
			var ex = fmod(float(ei * 175 + 60), float(MAP_COLS * TILE_SIZE))
			var ey = float(MAP_ROWS * TILE_SIZE) - et * float(MAP_ROWS * TILE_SIZE)
			draw_circle(Vector2(ex + sin(et * 7.0) * 8.0, ey), 2.5 * (1.0 - et), Color(1.0, 0.45, 0.1, (1.0 - et) * 0.85))
		
	# 2. Interactive Objects with Living Animations
	for c in objects.keys():
		if not revealed_cells.has(c):
			continue
		var obj = objects[c]
		var pos = cell_to_pixel(c)
		var type = obj.get("type", "")
		var tex: Texture2D = get_object_texture(obj)
		var is_combat = (type in ["encounter", "bandit_boss", "lich_boss", "dragon_boss"])
		
		# Shadow under object
		draw_circle(pos + Vector2(0, 15), 19.0, Color(0, 0, 0, 0.38))
		
		if is_combat:
			# Living breathing token for monsters and bosses
			var bob = sin(anim_timer * 2.8 + float(c.x * 5 + c.y * 11)) * 2.5
			var spr_pos = pos + Vector2(0, -6 + bob)
			var is_boss = (type in ["bandit_boss", "lich_boss", "dragon_boss"])
			var sz = Vector2(54, 54) if is_boss else Vector2(46, 46)
			
			if tex:
				draw_texture_rect(tex, Rect2(spr_pos - sz / 2.0, sz), false)
			
			# Token border rim
			var ring_rad = sz.x * 0.52
			if is_boss:
				var aura_col = Color(1.0, 0.3, 0.2, 0.9) if type != "lich_boss" else Color(0.75, 0.3, 1.0, 0.9)
				draw_arc(spr_pos, ring_rad + 2.0, 0.0, TAU, 28, Color(0, 0, 0, 0.7), 4.0)
				draw_arc(spr_pos, ring_rad + 2.0, 0.0, TAU, 28, aura_col, 2.5)
			else:
				draw_arc(spr_pos, ring_rad, 0.0, TAU, 28, Color(0.12, 0.08, 0.04, 0.8), 3.5)
				draw_arc(spr_pos, ring_rad, 0.0, TAU, 28, Color(0.85, 0.72, 0.3, 0.9), 1.8)
			
			# Crossed swords combat indicator badge (bottom-right corner)
			var badge_c = spr_pos + Vector2(sz.x * 0.34, sz.y * 0.32)
			draw_circle(badge_c, 9.5, Color(0.12, 0.05, 0.05, 0.95))
			draw_arc(badge_c, 9.5, 0.0, TAU, 16, Color(0.85, 0.22, 0.2, 0.9), 1.5)
			draw_line(badge_c + Vector2(-5, -5), badge_c + Vector2(5, 5), Color(0.95, 0.92, 0.85), 1.6)
			draw_line(badge_c + Vector2(5, -5), badge_c + Vector2(-5, 5), Color(0.95, 0.92, 0.85), 1.6)
		else:
			# Base icon for landmarks, chests, fountains
			if tex:
				var sz = Vector2(48, 48)
				draw_texture_rect(tex, Rect2(pos - sz / 2.0 + Vector2(0, -6), sz), false)
			
		# Living HoMM-style animations
		match type:
			"mill":
				# Animated rotating water wheel with spokes and water droplets
				var wheel_c = pos + Vector2(18, 4)
				var rot_ang = anim_timer * 2.8
				draw_circle(wheel_c, 13.0, Color(0.25, 0.16, 0.08, 0.75))
				draw_arc(wheel_c, 13.0, 0.0, TAU, 16, Color(0.65, 0.45, 0.22), 2.5)
				for i in range(6):
					var ang = rot_ang + float(i) * PI / 3.0
					var sp_end = wheel_c + Vector2(cos(ang), sin(ang)) * 13.0
					draw_line(wheel_c, sp_end, Color(0.85, 0.65, 0.35), 2.0)
				# Water splashes at wheel bottom
				for s_idx in range(3):
					var sp_x = wheel_c.x + sin(anim_timer * 7.0 + s_idx * 2.0) * 6.0
					var sp_y = wheel_c.y + 11.0 + absf(cos(anim_timer * 6.0 + s_idx)) * 4.0
					draw_circle(Vector2(sp_x, sp_y), 2.0, Color(0.8, 0.95, 1.0, 0.8))

			"fountain":
				# Pulsing mana aura and rising water droplets
				var pulse = sin(anim_timer * 3.5) * 4.0
				draw_arc(pos, 22.0 + pulse, 0.0, TAU, 24, Color(0.2, 0.8, 1.0, 0.7), 2.0)
				for k in range(3):
					var jt = fmod(anim_timer * 1.6 + k * 0.33, 1.0)
					var j_pos = pos + Vector2(sin(k * 2.5) * 5.0, -jt * 18.0)
					draw_circle(j_pos, 3.2 * (1.0 - jt * 0.4), Color(0.6, 0.95, 1.0, 0.85))

			"chest":
				# Periodic golden glint on lock
				var tw_t = fmod(anim_timer * 1.2 + float(c.x), 2.2)
				if tw_t < 0.5:
					var tw_alpha = sin(tw_t / 0.5 * PI)
					var tw_pos = pos + Vector2(8, -8)
					draw_line(tw_pos - Vector2(7, 0), tw_pos + Vector2(7, 0), Color(1, 0.95, 0.5, tw_alpha), 1.8)
					draw_line(tw_pos - Vector2(0, 7), tw_pos + Vector2(0, 7), Color(1, 0.95, 0.5, tw_alpha), 1.8)
					draw_circle(tw_pos, 2.8, Color(1, 1, 0.95, tw_alpha))

			"forester":
				# Chimney smoke puff
				var chim_pos = pos + Vector2(12, -18)
				for sm_i in range(3):
					var sm_t = fmod(anim_timer * 0.9 + sm_i * 0.33, 1.0)
					var sm_p = chim_pos + Vector2(sin(sm_t * 4.0) * 4.0, -sm_t * 16.0)
					draw_circle(sm_p, 2.2 + sm_t * 3.0, Color(0.85, 0.85, 0.9, (1.0 - sm_t) * 0.6))
				if not GameState.quest_forester_started:
					var f_y = pos.y - 32.0 + sin(anim_timer * 4.0) * 3.0
					draw_string(ThemeDB.fallback_font, Vector2(pos.x - 28, f_y), "📜 КВЕСТ", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.9, 0.2))

			"witch_hut":
				# Swamp Witch Hut: bubbling green cauldron and purple chimney fumes
				var chim_pos = pos + Vector2(12, -18)
				for sm_i in range(3):
					var sm_t = fmod(anim_timer * 0.85 + sm_i * 0.33, 1.0)
					var sm_p = chim_pos + Vector2(sin(sm_t * 5.0) * 5.0, -sm_t * 18.0)
					draw_circle(sm_p, 2.5 + sm_t * 3.5, Color(0.65, 0.35, 0.85, (1.0 - sm_t) * 0.7))
				var cauld_pos = pos + Vector2(-16, 8)
				draw_circle(cauld_pos, 6.5, Color(0.18, 0.15, 0.15))
				draw_circle(cauld_pos + Vector2(0, -2), 4.5, Color(0.35, 0.95, 0.25, 0.9))
				if not GameState.quest_forester_started:
					var f_y = pos.y - 32.0 + sin(anim_timer * 4.0) * 3.0
					draw_string(ThemeDB.fallback_font, Vector2(pos.x - 28, f_y), "📜 ВЕДЬМА", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0.8, 1.0, 0.4))

			"crypt":
				# Sunken Crypt: eerie emerald glow and floating spectral wisps
				draw_arc(pos, 22.0, 0.0, TAU, 24, Color(0.2, 0.8, 0.4, 0.6), 2.0)
				for wi in range(3):
					var wt = fmod(anim_timer * 1.3 + wi * 0.33, 1.0)
					var wp = pos + Vector2(sin(wt * 5.0 + wi) * 8.0, 4.0 - wt * 22.0)
					draw_circle(wp, 2.8 * (1.0 - wt * 0.5), Color(0.3, 0.95, 0.55, (1.0 - wt) * 0.8))

			"druid_camp":
				# Menhir Stone Circle with emerald druid campfire
				draw_arc(pos, 20.0, 0.0, TAU, 16, Color(0.3, 0.8, 0.45, 0.5), 2.0)
				for di in range(5):
					var d_ang = float(di) * TAU / 5.0
					var d_pos = pos + Vector2(cos(d_ang), sin(d_ang)) * 17.0
					draw_rect(Rect2(d_pos.x - 3, d_pos.y - 5, 6, 10), Color(0.32, 0.36, 0.32))
				var df = sin(anim_timer * 11.0) * 2.0
				draw_circle(pos, 4.5 + df, Color(0.2, 0.9, 0.4, 0.85))
				draw_circle(pos, 2.0, Color(0.8, 1.0, 0.6, 0.95))

			"bandit_boss", "lich_boss", "dragon_boss":
				# Ominous crimson/purple/fiery aura
				var b_pulse = sin(anim_timer * 3.0) * 3.0
				var aura_col = Color(1.0, 0.2, 0.15, 0.85) if type != "lich_boss" else Color(0.7, 0.2, 1.0, 0.85)
				draw_arc(pos, 28.0 + b_pulse, 0.0, TAU, 24, aura_col, 3.5)
				# Dancing campfire flames at side of tent
				var fire_c = pos + Vector2(14, 10)
				var fl_h = 11.0 + sin(anim_timer * 12.0) * 4.0
				draw_colored_polygon([fire_c + Vector2(-6, 4), fire_c + Vector2(6, 4), fire_c + Vector2(0, 4 - fl_h)], Color(1.0, 0.4, 0.05, 0.95))
				draw_colored_polygon([fire_c + Vector2(-3, 4), fire_c + Vector2(3, 4), fire_c + Vector2(0, 4 - fl_h * 0.65)], Color(1.0, 0.95, 0.2, 0.95))
				# Rising ember sparks
				for sp_i in range(3):
					var st = fmod(anim_timer * 1.5 + sp_i * 0.4, 1.0)
					var spk_pos = fire_c + Vector2(sin(st * 8.0 + sp_i) * 5.0, 4.0 - st * 20.0)
					draw_circle(spk_pos, 2.0 * (1.0 - st), Color(1.0, 0.7, 0.1, 1.0 - st))
				if (GameState.flags.get("iron_gate_opened", false) or GameState.flags.get("bone_gate_opened", false) or GameState.flags.get("dragon_gate_opened", false)):
					var bb_y = pos.y - 34.0 + sin(anim_timer * 4.0) * 3.0
					draw_string(ThemeDB.fallback_font, Vector2(pos.x - 30, bb_y), "⚔ БОСС", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.35, 0.3))

			"fairy_shrine", "druid_altar", "dragon_altar":
				# Shimmering golden-emerald halo and orbiting fairy motes
				draw_arc(pos, 28.0, 0.0, TAU, 24, Color(0.95, 0.85, 0.2, 0.85), 3.0)
				for f_idx in range(4):
					var f_ang = anim_timer * 2.2 + float(f_idx) * PI * 0.5
					var f_rad = 22.0 + sin(anim_timer * 3.0 + f_idx) * 3.5
					var f_pos = pos + Vector2(cos(f_ang) * f_rad, sin(f_ang) * f_rad * 0.65)
					draw_circle(f_pos, 3.5, Color(0.4, 1.0, 0.6, 0.85))
					draw_circle(f_pos, 1.8, Color(1.0, 1.0, 0.9, 0.95))
				
				# High-priority Crown / Altar Return Beacon!
				if (GameState.has_fairy_crown or GameState.flags.get("lich_defeated", false) or GameState.flags.get("dragon_defeated", false)) and not GameState.quest_completed:
					var beacon_wave = fmod(anim_timer * 1.5, 1.0)
					var wave_rad = 24.0 + beacon_wave * 26.0
					var wave_alpha = (1.0 - beacon_wave) * 0.85
					draw_arc(pos, wave_rad, 0.0, TAU, 32, Color(1.0, 0.85, 0.1, wave_alpha), 3.5)
					var b_y = pos.y - 36.0 + sin(anim_timer * 5.0) * 4.0
					draw_string(ThemeDB.fallback_font, Vector2(pos.x - 30, b_y), "👑 СЮДА!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.95, 0.3))

			"bone_gate":
				# Bone Archway with spectral green torches
				var t1 = pos + Vector2(-16, -4)
				var t2 = pos + Vector2(16, -4)
				var tf = sin(anim_timer * 13.0) * 2.0
				draw_circle(t1, 5.0 + tf, Color(0.2, 0.9, 0.45, 0.85))
				draw_circle(t1, 2.5, Color(0.8, 1.0, 0.6, 0.95))
				draw_circle(t2, 5.0 - tf, Color(0.2, 0.9, 0.45, 0.85))
				draw_circle(t2, 2.5, Color(0.8, 1.0, 0.6, 0.95))
				var is_opened = GameState.flags.get("bone_gate_opened", false)
				if is_opened:
					draw_arc(pos, 22.0, PI, TAU, 16, Color(0.3, 0.95, 0.4, 0.85), 3.0)
				elif GameState.has_gate_key:
					var g_y = pos.y - 32.0 + sin(anim_timer * 4.5) * 3.0
					draw_string(ThemeDB.fallback_font, Vector2(pos.x - 26, g_y), "🗝 ВРАТА!", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0.4, 1.0, 0.6))

			"gate", "dragon_gate":
				# Torches on gate posts
				var t1 = pos + Vector2(-16, -4)
				var t2 = pos + Vector2(16, -4)
				var tf = sin(anim_timer * 13.0) * 2.0
				draw_circle(t1, 5.0 + tf, Color(1.0, 0.55, 0.1, 0.85))
				draw_circle(t1, 2.5, Color(1.0, 0.95, 0.4, 0.95))
				draw_circle(t2, 5.0 - tf, Color(1.0, 0.55, 0.1, 0.85))
				draw_circle(t2, 2.5, Color(1.0, 0.95, 0.4, 0.95))
				var is_opened = GameState.flags.get("iron_gate_opened", false) or GameState.flags.get("dragon_gate_opened", false)
				if is_opened:
					draw_arc(pos, 22.0, PI, TAU, 16, Color(0.4, 0.95, 0.4, 0.8), 3.0)
				elif GameState.has_gate_key:
					var g_y = pos.y - 32.0 + sin(anim_timer * 4.5) * 3.0
					draw_string(ThemeDB.fallback_font, Vector2(pos.x - 26, g_y), "🗝 ВРАТА!", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.85, 0.2))

			"upgrade_altar":
				# Radiant altar with spinning stars
				draw_arc(pos, 24.0, 0.0, TAU, 24, Color(0.9, 0.8, 0.2, 0.8), 2.5)
				for u_i in range(3):
					var u_ang = anim_timer * 2.0 + float(u_i) * TAU / 3.0
					var u_p = pos + Vector2(cos(u_ang), sin(u_ang)) * 16.0
					draw_circle(u_p, 3.0, Color(1.0, 0.95, 0.5, 0.9))

		# Player Ownership Pennants / Banners over visited & claimed landmarks
		var is_claimed = false
		var obj_id = obj.get("id", "")
		match type:
			"mill":
				is_claimed = GameState.flags.get(obj_id, false)
			"fairy_dwelling":
				is_claimed = GameState.flags.get(obj_id, false) or GameState.dwelling_stock.get("fairy_camp", 14) < 14
			"fountain":
				is_claimed = GameState.flags.get(obj_id, false)
			"fairy_shrine":
				is_claimed = GameState.flags.get(obj_id, false)
			"druid_camp":
				is_claimed = GameState.flags.get(obj_id, false) or GameState.dwelling_stock.get("druid_camp", 8) < 8
			"forge":
				is_claimed = GameState.flags.get(obj_id, false)
			"griffin_roost":
				is_claimed = GameState.flags.get(obj_id, false) or GameState.dwelling_stock.get("griffin_nest", 6) < 6

		if is_claimed:
			_draw_player_banner(pos)

	# 3. HoMM Movement Path (Planned route or hover preview)
	var active_path = planned_path if planned_path.size() > 0 else preview_path
	if active_path.size() > 0:
		var mp_left = GameState.move_points
		var accum_cost = 0
		var has_pf = GameState.has_skill("pathfinding") if GameState.has_method("has_skill") else false
		var is_locked = (planned_path.size() > 0)
		for i in range(active_path.size()):
			var p_cell = active_path[i]
			var step_cost = 1 if road_cells.has(p_cell) else (1 if has_pf else 2)
			accum_cost += step_cost
			if not revealed_cells.has(p_cell):
				continue
			var p_pos = cell_to_pixel(p_cell)
			var is_reachable = (accum_cost <= mp_left)
			
			var dot_color = Color(0.15, 0.88, 0.25, 0.9) if is_reachable else Color(0.92, 0.22, 0.15, 0.9)
			var r_outer = 8.0 if is_locked else 6.0
			var r_inner = 4.0 if is_locked else 3.0
			draw_circle(p_pos, r_outer, dot_color)
			draw_circle(p_pos, r_inner, Color(1, 1, 1, 0.95))
			
		# Target Ring at goal
		var goal_cell = active_path[-1]
		if revealed_cells.has(goal_cell):
			var goal_pos = cell_to_pixel(goal_cell)
			var ring_color = Color(1.0, 0.85, 0.2, 0.95)
			if objects.has(goal_cell) and objects[goal_cell].get("type", "") == "encounter":
				ring_color = Color(1.0, 0.25, 0.2, 0.95)
			draw_arc(goal_pos, 24.0, 0.0, TAU, 32, ring_color, 3.5)
			if is_locked:
				draw_circle(goal_pos, 5.0, ring_color)
		
	# 4. Knight on Horse
	var hero_pos = hero_pixel_pos
	var bob_y = sin(walk_anim_timer) * 4.0 if is_moving else sin(anim_timer * 2.2) * 1.5
	
	# Horse shadow
	_draw_oval_shadow(hero_pos + Vector2(0, 16), 24, 10, Color(0, 0, 0, 0.4))
	
	# Pick directional sprite based on movement/facing direction
	var cur_tex: Texture2D = tex_hero_side if tex_hero_side else tex_hero
	var sx = 1.0
	var tilt = 0.0

	if facing_dir.y < 0 and abs(facing_dir.y) >= abs(facing_dir.x):
		# Facing UP / North (back of horse & knight)
		cur_tex = tex_hero_up if tex_hero_up else cur_tex
		sx = -1.0 if facing_dir.x < 0 else 1.0
		tilt = (0.04 if facing_dir.x >= 0 else -0.04) if is_moving else 0.0
	elif facing_dir.y > 0 and abs(facing_dir.y) >= abs(facing_dir.x):
		# Facing DOWN / South (front of horse & knight)
		cur_tex = tex_hero_down if tex_hero_down else cur_tex
		sx = -1.0 if facing_dir.x < 0 else 1.0
		tilt = (-0.04 if facing_dir.x >= 0 else 0.04) if is_moving else 0.0
	else:
		# Facing LEFT or RIGHT (side profile)
		cur_tex = tex_hero_side if tex_hero_side else cur_tex
		sx = 1.0 if facing_right else -1.0
		if is_moving:
			tilt = (0.09 if facing_right else -0.09)
			if move_dir.y < 0:
				tilt -= 0.05
			elif move_dir.y > 0:
				tilt += 0.05

	if cur_tex:
		var h_sz = Vector2(68, 64)
		var spr_pivot = hero_pos + Vector2(0, 16 + bob_y)
		draw_set_transform(spr_pivot, tilt, Vector2(sx, 1.0))
		var local_rect = Rect2(-h_sz.x / 2.0, -h_sz.y, h_sz.x, h_sz.y)
		draw_texture_rect(cur_tex, local_rect, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
			
	# Active selection ring under knight
	draw_arc(hero_pos + Vector2(0, 8), 24.0, 0.0, TAU, 24, Color(0.95, 0.82, 0.3, 0.75), 2.5)
	# Quest compass: golden arrow orbiting the hero, pointing at the objective
	if objective_cell.x >= 0 and objective_cell != hero_cell:
		var target_px = cell_to_pixel(objective_cell)
		var dir_vec = (target_px - hero_pos)
		if dir_vec.length() > 60.0:
			var ang = dir_vec.angle()
			var orbit_r = 44.0 + sin(anim_timer * 4.0) * 4.0
			var tip = hero_pos + Vector2(cos(ang), sin(ang)) * orbit_r
			var wing_a = tip - Vector2(cos(ang - 0.5), sin(ang - 0.5)) * 12.0
			var wing_b = tip - Vector2(cos(ang + 0.5), sin(ang + 0.5)) * 12.0
			draw_colored_polygon(PackedVector2Array([tip, wing_a, wing_b]), Color(1.0, 0.85, 0.2, 0.9))
			draw_circle(tip, 3.0, Color(1.0, 0.95, 0.6, 0.95))

	
	# 5. Fog of War (100% Solid Opaque Shroud)
	for y in range(MAP_ROWS):
		for x in range(MAP_COLS):
			var c = Vector2i(x, y)
			if not revealed_cells.has(c):
				var r = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				draw_rect(r, Color(0.02, 0.03, 0.05, 1.0))

	# 6. Hover Highlight & Object Tooltip (HoMM3 Style)
	if hovered_cell != Vector2i(-1, -1) and revealed_cells.has(hovered_cell):
		var h_rect = Rect2(hovered_cell.x * TILE_SIZE, hovered_cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(h_rect, Color(1.0, 1.0, 0.4, 0.12))
		draw_rect(h_rect, Color(1.0, 0.85, 0.3, 0.65), false, 2.0)
		
		if objects.has(hovered_cell):
			var obj = objects[hovered_cell]
			var obj_type = obj.get("type", "")
			var obj_name = obj.get("name", "Объект")
			var obj_hint = ""
			match obj_type:
				"mill":
					obj_hint = "Мельница (+500 золота в неделю)" if not GameState.flags.get(obj.get("id", ""), false) else "Мельница (Посещено)"
				"chest":
					obj_hint = "Сундук (+1000 зол / +600 опыта)"
				"fountain":
					obj_hint = "Святилище (+1 Магия, мана)" if not GameState.flags.get(obj.get("id", ""), false) else "Святилище (Мана)"
				"fairy_dwelling":
					var av = GameState.dwelling_stock.get("fairy_camp", 0)
					obj_hint = "Роща Фей (Доступно: %d)" % av
				"druid_camp":
					var av2 = GameState.dwelling_stock.get("druid_camp", 0)
					obj_hint = "Круг Друидов (Доступно: %d)" % av2
				"griffin_roost":
					var av3 = GameState.dwelling_stock.get("griffin_nest", 0)
					obj_hint = "Гнездовье (Доступно: %d)" % av3
				"encounter":
					obj_hint = "Вражеский Дозор (Орда)" if not GameState.flags.get(obj.get("id", ""), false) else "Дозор (Разбит)"
				"bandit_boss":
					obj_hint = "Атаман Разбойников (Венец Фей)" if not GameState.flags.get("bandit_boss", false) else "Лагерь атамана (Сожжен)"
				"lich_boss":
					obj_hint = "Цитадель Лича (Кольцо Архимага)" if not GameState.flags.get("lich_defeated", false) else "Цитадель Лича (Разрушена)"
				"dragon_boss":
					obj_hint = "Красный Дракон (Панцирь Стража)" if not GameState.flags.get("dragon_defeated", false) else "Логово Дракона (Повержен)"
				"forester", "witch_hut":
					obj_hint = "Хижина хранителя квеста"
				"gate", "bone_gate", "dragon_gate":
					var is_op = GameState.flags.get("iron_gate_opened", false) or GameState.flags.get("bone_gate_opened", false) or GameState.flags.get("dragon_gate_opened", false)
					obj_hint = "Врата (Открыты)" if is_op else "Врата (Нужен ключ)"
				"obelisk", "upgrade_altar", "forge":
					obj_hint = "Святыня Силы (+характеристики)"
				"fairy_shrine", "druid_altar", "dragon_altar":
					obj_hint = "Святилище Триумфа"
				_:
					obj_hint = "Исследовать местность"

			var font = ThemeDB.fallback_font
			var f_size_name = 13
			var f_size_hint = 11
			var line1 = obj_name
			var line2 = obj_hint
			var w1 = font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size_name).x
			var w2 = font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size_hint).x if line2 != "" else 0.0
			var box_w = maxf(w1, w2) + 24.0
			var box_h = 44.0 if line2 != "" else 28.0
			
			var t_center = cell_to_pixel(hovered_cell)
			var box_x = clampf(t_center.x - box_w / 2.0, 10.0, MAP_COLS * TILE_SIZE - box_w - 10.0)
			var box_y = t_center.y - TILE_SIZE * 0.75 - box_h
			if box_y < 10.0:
				box_y = t_center.y + TILE_SIZE * 0.75
				
			var tip_rect = Rect2(box_x, box_y, box_w, box_h)
			draw_rect(Rect2(box_x + 3, box_y + 3, box_w, box_h), Color(0, 0, 0, 0.45), true)
			draw_rect(tip_rect, Color(0.96, 0.91, 0.78, 0.96), true)
			draw_rect(tip_rect, Color(0.45, 0.28, 0.12, 0.9), false, 2.0)
			draw_rect(Rect2(box_x + 2, box_y + 2, box_w - 4, box_h - 4), Color(0.85, 0.7, 0.25, 0.8), false, 1.0)
			
			draw_string(font, Vector2(box_x + 12, box_y + 17), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size_name, Color(0.2, 0.1, 0.05))
			if line2 != "":
				draw_string(font, Vector2(box_x + 12, box_y + 33), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size_hint, Color(0.42, 0.28, 0.12))

func _draw_oval_shadow(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(16):
		var ang = deg_to_rad(float(i) * 360.0 / 16.0)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, color)

func _draw_forest_cell(c: Vector2i, r: Rect2) -> void:
	if forest_cells.has(c):
		if tex_forest:
			draw_texture_rect(tex_forest, r, false)
		else:
			draw_rect(r, Color(0.1, 0.25, 0.12))
	elif road_cells.has(c):
		if tex_dirt:
			draw_texture_rect(tex_dirt, r, false)
		else:
			draw_rect(r, Color(0.45, 0.32, 0.18))
	else:
		var var_idx = (c.x * 7 + c.y * 13) % max(1, tex_grass.size())
		if tex_grass.size() > 0:
			draw_texture_rect(tex_grass[var_idx], r, false)
		else:
			draw_rect(r, Color(0.25, 0.48, 0.2))

func _draw_swamp_cell(c: Vector2i, r: Rect2) -> void:
	if forest_cells.has(c):
		# Impassable Mire / Gnarled Cypress Swamp
		draw_rect(r, Color(0.13, 0.18, 0.13))
		# Murky stagnant pool under roots
		draw_circle(r.get_center() + Vector2(0, 10), 22.0, Color(0.08, 0.13, 0.10, 0.95))
		# Duckweed specks
		draw_circle(r.get_center() + Vector2(-12, 14), 3.0, Color(0.24, 0.38, 0.16, 0.8))
		draw_circle(r.get_center() + Vector2(14, 12), 4.0, Color(0.28, 0.42, 0.18, 0.8))
		# Gnarled trunk and roots
		var tc = r.get_center()
		draw_line(tc + Vector2(-2, -6), tc + Vector2(-14, 20), Color(0.24, 0.16, 0.10), 3.5)
		draw_line(tc + Vector2(2, -6), tc + Vector2(14, 20), Color(0.24, 0.16, 0.10), 3.5)
		draw_line(tc + Vector2(0, -6), tc + Vector2(0, 22), Color(0.20, 0.14, 0.08), 4.0)
		# Canopy foliage
		draw_circle(tc + Vector2(0, -14), 16.0, Color(0.18, 0.28, 0.16))
		draw_circle(tc + Vector2(-10, -10), 12.0, Color(0.16, 0.25, 0.15))
		draw_circle(tc + Vector2(10, -10), 12.0, Color(0.20, 0.30, 0.18))
		# Hanging Spanish moss (испанский мох)
		for mi in range(4):
			var mx = tc.x - 12.0 + float(mi) * 8.0
			var mh = 8.0 + float((mi * 3) % 7)
			draw_line(Vector2(mx, tc.y - 4), Vector2(mx, tc.y - 4 + mh), Color(0.44, 0.55, 0.40, 0.75), 1.8)
	elif road_cells.has(c):
		# WOODEN PLANK CAUSEWAY (ГААТЬ / НАСТИЛ ИЗ ДОСОК)
		# Dark stagnant mire foundation
		draw_rect(r, Color(0.15, 0.20, 0.15))
		var n = road_cells.has(c + Vector2i(0, -1))
		var s = road_cells.has(c + Vector2i(0, 1))
		var e = road_cells.has(c + Vector2i(1, 0))
		var w = road_cells.has(c + Vector2i(-1, 0))
		
		if (w or e) and not (n and s):
			# Horizontal causeway boardwalk
			# Longitudinal dark log beams
			draw_line(Vector2(r.position.x, r.position.y + 14), Vector2(r.end.x, r.position.y + 14), Color(0.22, 0.15, 0.09), 3.5)
			draw_line(Vector2(r.position.x, r.position.y + 50), Vector2(r.end.x, r.position.y + 50), Color(0.22, 0.15, 0.09), 3.5)
			# 6 transverse wooden planks
			for i in range(6):
				var px = r.position.x + 3 + i * 10
				var p_col = Color(0.44, 0.35, 0.23) if (i + c.x) % 2 == 0 else Color(0.38, 0.29, 0.18)
				draw_rect(Rect2(px, r.position.y + 13, 8.5, 38), p_col)
				draw_rect(Rect2(px, r.position.y + 13, 8.5, 38), Color(0.18, 0.12, 0.08), false, 1.0)
				# Iron nail heads
				draw_circle(Vector2(px + 4.2, r.position.y + 17), 1.2, Color(0.12, 0.08, 0.06))
				draw_circle(Vector2(px + 4.2, r.position.y + 47), 1.2, Color(0.12, 0.08, 0.06))
		elif (n or s) and not (w and e):
			# Vertical causeway boardwalk
			# Longitudinal dark log beams
			draw_line(Vector2(r.position.x + 14, r.position.y), Vector2(r.position.x + 14, r.end.y), Color(0.22, 0.15, 0.09), 3.5)
			draw_line(Vector2(r.position.x + 50, r.position.y), Vector2(r.position.x + 50, r.end.y), Color(0.22, 0.15, 0.09), 3.5)
			# 6 transverse wooden planks
			for i in range(6):
				var py = r.position.y + 3 + i * 10
				var p_col = Color(0.44, 0.35, 0.23) if (i + c.y) % 2 == 0 else Color(0.38, 0.29, 0.18)
				draw_rect(Rect2(r.position.x + 13, py, 38, 8.5), p_col)
				draw_rect(Rect2(r.position.x + 13, py, 38, 8.5), Color(0.18, 0.12, 0.08), false, 1.0)
				# Iron nail heads
				draw_circle(Vector2(r.position.x + 17, py + 4.2), 1.2, Color(0.12, 0.08, 0.06))
				draw_circle(Vector2(r.position.x + 47, py + 4.2), 1.2, Color(0.12, 0.08, 0.06))
		else:
			# Junction / Crossroads boardwalk platform
			draw_rect(Rect2(r.position.x + 10, r.position.y + 10, 44, 44), Color(0.40, 0.32, 0.20))
			draw_rect(Rect2(r.position.x + 10, r.position.y + 10, 44, 44), Color(0.20, 0.14, 0.08), false, 2.0)
			for i in range(4):
				draw_line(Vector2(r.position.x + 10, r.position.y + 10 + i * 11), Vector2(r.position.x + 54, r.position.y + 10 + i * 11), Color(0.18, 0.12, 0.08), 1.0)
			# Piles
			draw_circle(Vector2(r.position.x + 12, r.position.y + 12), 3.0, Color(0.25, 0.18, 0.10))
			draw_circle(Vector2(r.end.x - 12, r.position.y + 12), 3.0, Color(0.25, 0.18, 0.10))
			draw_circle(Vector2(r.position.x + 12, r.end.y - 12), 3.0, Color(0.25, 0.18, 0.10))
			draw_circle(Vector2(r.end.x - 12, r.end.y - 12), 3.0, Color(0.25, 0.18, 0.10))
		# Moss on causeway edge
		draw_circle(r.position + Vector2(14, 16), 3.5, Color(0.24, 0.36, 0.20, 0.6))
	else:
		# Walkable Peat Bog & Swamp Mire
		draw_rect(r, Color(0.22, 0.29, 0.20))
		var v = (c.x * 13 + c.y * 37) % 8
		if v < 3:
			# Stagnant water puddle with lily pad
			var pool_c = r.get_center() + Vector2(sin(float(c.x)) * 8.0, cos(float(c.y)) * 8.0)
			draw_circle(pool_c, 16.0, Color(0.10, 0.16, 0.14, 0.9))
			draw_circle(pool_c, 12.0, Color(0.08, 0.13, 0.12, 0.95))
			draw_circle(pool_c + Vector2(-5, -3), 4.5, Color(0.26, 0.55, 0.24))
			draw_circle(pool_c + Vector2(6, 4), 3.5, Color(0.22, 0.48, 0.20))
			draw_circle(pool_c + Vector2(-5, -3), 1.5, Color(0.95, 0.9, 0.9))
		elif v == 3 or v == 4:
			# Swamp reeds / cattails
			var reed_base = r.get_center() + Vector2(4, 12)
			for ri in range(3):
				var rx = reed_base.x + float(ri - 1) * 7.0
				draw_line(Vector2(rx, reed_base.y), Vector2(rx - 1.0, reed_base.y - 18), Color(0.28, 0.40, 0.22), 1.5)
				draw_line(Vector2(rx - 1.0, reed_base.y - 14), Vector2(rx - 1.0, reed_base.y - 8), Color(0.38, 0.24, 0.14), 2.5)
		else:
			# Mossy peat hummocks
			var hm = r.get_center()
			draw_circle(hm + Vector2(-6, 4), 9.0, Color(0.18, 0.25, 0.17))
			draw_circle(hm + Vector2(8, -4), 7.0, Color(0.25, 0.34, 0.22))
			draw_circle(hm + Vector2(8, -4), 3.0, Color(0.35, 0.45, 0.26))
		
		# Rising swamp gas bubble
		if (c.x * 5 + c.y * 13) % 7 == 0:
			var bt = fmod(anim_timer * 1.6 + float(c.x * 2), 2.0)
			var bp = r.get_center() + Vector2(sin(bt * 4.0) * 4.0, 10.0 - bt * 16.0)
			draw_circle(bp, 2.5 * (1.0 - bt * 0.4), Color(0.5, 0.75, 0.4, (1.0 - bt / 2.0) * 0.7))

func _draw_volcano_cell(c: Vector2i, r: Rect2) -> void:
	if forest_cells.has(c):
		# Jagged basalt ridge with lava cracks
		draw_rect(r, Color(0.12, 0.10, 0.12))
		draw_line(r.position + Vector2(10, 50), r.position + Vector2(32, 10), Color(0.22, 0.18, 0.20), 4.0)
		draw_line(r.position + Vector2(32, 10), r.position + Vector2(54, 50), Color(0.22, 0.18, 0.20), 4.0)
		# Glowing lava crack
		draw_line(r.position + Vector2(24, 34), r.position + Vector2(40, 34), Color(1.0, 0.35, 0.05, 0.85), 2.0)
	elif road_cells.has(c):
		# Obsidian stone road
		draw_rect(r, Color(0.28, 0.22, 0.24))
		draw_rect(r, Color(0.15, 0.10, 0.12), false, 2.0)
	else:
		# Ash wasteland
		draw_rect(r, Color(0.18, 0.15, 0.16))
		if (c.x * 7 + c.y * 11) % 6 == 0:
			draw_line(r.get_center() - Vector2(8, 0), r.get_center() + Vector2(8, 0), Color(0.9, 0.3, 0.05, 0.6), 1.5)

func _draw_player_banner(pos: Vector2) -> void:
	var pole_base = pos + Vector2(16, 4)
	var pole_top = pos + Vector2(16, -26)
	
	# Flagpole
	draw_line(pole_base, pole_top, Color(0.35, 0.22, 0.12), 2.5)
	draw_circle(pole_top, 2.8, Color(1.0, 0.85, 0.2))
	
	# Fluttering royal blue pennant
	var flutter = sin(anim_timer * 4.5 + pos.x * 0.1) * 2.5
	var p1 = pole_top + Vector2(1, 2)
	var p2 = pole_top + Vector2(20 + flutter, 8)
	var p3 = pole_top + Vector2(1, 14)
	var banner_points = PackedVector2Array([p1, p2, p3])
	draw_colored_polygon(banner_points, Color(0.12, 0.42, 0.95, 0.95))
	
	# Gold border trim on pennant
	draw_polyline(PackedVector2Array([p1, p2, p3, p1]), Color(1.0, 0.88, 0.25, 0.95), 1.5)
	
	# Golden royal emblem
	draw_circle(pole_top + Vector2(7, 8), 2.0, Color(1.0, 0.95, 0.45))

