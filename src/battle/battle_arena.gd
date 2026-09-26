class_name BattleArena
extends Control

signal battle_finished(victory: bool, rewards: Dictionary)

const HEX_SIZE: float = 62.0
const GRID_COLS: int = 11
const GRID_ROWS: int = 7

# Visual styling
const COLOR_HEX_OUTLINE := Color(0.9, 0.85, 0.5, 0.45)
const COLOR_HEX_FILL := Color(0.1, 0.25, 0.15, 0.12)
const COLOR_MOVE_REACHABLE := Color(0.3, 0.7, 1.0, 0.4)
const COLOR_ATTACK_TARGET := Color(1.0, 0.35, 0.2, 0.55)
const COLOR_ACTIVE_HEX := Color(1.0, 0.9, 0.3, 0.7)

var grid_origin: Vector2 = Vector2(340, 220)
var field_bounds: Rect2i = Rect2i(0, 0, GRID_COLS, GRID_ROWS)

var all_stacks: Array[BattleStack] = []
var turn_queue: Array[BattleStack] = []
var current_actor: BattleStack = null
var current_round: int = 1

var obstacles: Array[Vector2i] = [
	Vector2i(3, 2), Vector2i(7, 4), Vector2i(5, 5), Vector2i(4, 1)
]

var reachable_hexes: Array[Vector2i] = []
var attackable_targets: Array[BattleStack] = []

# Hover damage forecast & broken arrow
var hovered_target: BattleStack = null
var hovered_is_broken: bool = false
var hovered_forecast: Dictionary = {}
var hovered_threat_hexes: Array[Vector2i] = []

var pending_spell_id: String = ""
var hero_cast_this_round: bool = false
var is_ai_turn: bool = false
var is_animating: bool = false

# Mobile touch variables
var touch_down_time: float = 0.0
var touch_down_pos: Vector2 = Vector2.ZERO
var touch_candidate: BattleStack = null

# UI Nodes
@onready var arena_viewport: ArenaViewport = $ArenaViewport
@onready var initiative_container: HBoxContainer = $CanvasLayer/TopBar/InitiativeScroll/InitiativeTokens
@onready var hero_mana_label: Label = $CanvasLayer/HeroHUD/Parchment/HeroStats/ManaLabel
@onready var hero_mana_bar: ProgressBar = $CanvasLayer/HeroHUD/Parchment/HeroStats/ManaBar
@onready var round_label: Label = $CanvasLayer/TopBar/RoundLabel
@onready var log_label: Label = $CanvasLayer/BottomBar/CombatLogLabel
@onready var spellbook_dialog: Control = $CanvasLayer/SpellbookDialog
@onready var unit_info_dialog: Control = $CanvasLayer/UnitInfoDialog
@onready var unit_info_portrait: TextureRect = $CanvasLayer/UnitInfoDialog/Parchment/UnitPortrait
@onready var unit_info_stats: Label = $CanvasLayer/UnitInfoDialog/Parchment/StatsLabel
@onready var victory_dialog: Control = $CanvasLayer/VictoryDialog
@onready var victory_title: Label = $CanvasLayer/VictoryDialog/Parchment/Title
@onready var victory_desc: Label = $CanvasLayer/VictoryDialog/Parchment/Description

var floating_texts: Array[Dictionary] = []
var is_auto_battling: bool = false
var auto_battle_btn: Button
var defend_btn: Button
var wait_btn: Button
var retreat_btn: Button

func _ready() -> void:
	SoundManager.play_music("res://assets/audio/music/battle_theme.wav")
	_init_battle()
	defend_btn = $CanvasLayer/HeroHUD/Parchment/DefendBtn
	wait_btn = $CanvasLayer/HeroHUD/Parchment/WaitBtn
	defend_btn.text = "🛡️ Защита"
	defend_btn.offset_left = 16.0
	defend_btn.offset_right = 126.0

	wait_btn.text = "⏳ Ждать"
	wait_btn.offset_left = 136.0
	wait_btn.offset_right = 246.0

	auto_battle_btn = Button.new()
	auto_battle_btn.name = "AutoBattleBtn"
	auto_battle_btn.text = "⚡ Авто"
	auto_battle_btn.offset_left = 256.0
	auto_battle_btn.offset_right = 368.0
	auto_battle_btn.offset_top = defend_btn.offset_top
	auto_battle_btn.offset_bottom = defend_btn.offset_bottom
	auto_battle_btn.add_theme_font_size_override("font_size", 16)
	auto_battle_btn.pressed.connect(_toggle_auto_battle)
	$CanvasLayer/HeroHUD/Parchment.add_child(auto_battle_btn)

	# Retreat / Exit to Menu button
	retreat_btn = Button.new()
	retreat_btn.name = "RetreatBtn"
	retreat_btn.text = "↩️ В Меню" if GameState.is_demo_battle else "🏳️ Отступить"
	retreat_btn.offset_left = 24.0
	retreat_btn.offset_top = 20.0
	retreat_btn.offset_right = 150.0
	retreat_btn.offset_bottom = 62.0
	retreat_btn.add_theme_font_size_override("font_size", 15)
	retreat_btn.pressed.connect(_on_retreat_pressed)
	$CanvasLayer.add_child(retreat_btn)

	defend_btn.pressed.connect(_on_defend_pressed)
	wait_btn.pressed.connect(_on_wait_pressed)
	$CanvasLayer/SpellbookBtn.pressed.connect(_on_spellbook_btn_pressed)
	$CanvasLayer/SpellbookDialog/Parchment/CloseBtn.pressed.connect(func(): spellbook_dialog.hide())
	$CanvasLayer/UnitInfoDialog/Parchment/CloseBtn.pressed.connect(func(): unit_info_dialog.hide())
	$CanvasLayer/VictoryDialog/Parchment/ContinueBtn.pressed.connect(_on_victory_continue)
	
	_setup_spell_buttons()
	_update_ui()
	_start_round()

func _on_retreat_pressed() -> void:
	SoundManager.play_sfx("click")
	if GameState.is_demo_battle:
		GameState.is_demo_battle = false
		var pref = SoundManager.load_music_preference()
		var theme_to_play = pref if pref != "" else "res://assets/audio/music/themes/homm2_01_sorceress_garden.wav"
		SoundManager.play_music(theme_to_play)
		get_tree().change_scene_to_file("res://src/main.tscn")
	else:
		_show_victory(false)

func _init_battle() -> void:
	all_stacks.clear()
	obstacles.clear()
	
	if GameState.is_demo_battle:
		obstacles = [Vector2i(3, 2), Vector2i(7, 4), Vector2i(5, 5), Vector2i(4, 1)]
		var p_army = GameState.demo_player_army if GameState.demo_player_army.size() > 0 else GameState.player_army
		var p_hexes = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5)]
		for i in range(min(p_army.size(), p_hexes.size())):
			var item = p_army[i]
			if item.get("count", 0) > 0:
				var stack = BattleStack.new()
				stack.setup(item["unit_id"], item["count"], 0, p_hexes[i])
				all_stacks.append(stack)
		
		var e_configs = GameState.demo_enemy_configs
		if e_configs.is_empty():
			e_configs = [
				{"unit_id": "goblin", "count": 18, "hex": Vector2i(10, 1)},
				{"unit_id": "wolf", "count": 9, "hex": Vector2i(10, 3)},
				{"unit_id": "treant", "count": 2, "hex": Vector2i(10, 5)}
			]
		for cfg in e_configs:
			var stack = BattleStack.new()
			stack.setup(cfg["unit_id"], cfg["count"], 1, cfg["hex"])
			all_stacks.append(stack)
			
		log_combat("⚔️ Демонстрационный бой [%s]: %s!" % [GameState.demo_difficulty_title, GameState.demo_encounter_title])
		return

	# Chapter-specific obstacles
	match GameState.current_chapter:
		1:
			obstacles = [Vector2i(3, 2), Vector2i(7, 4), Vector2i(5, 5), Vector2i(4, 1)]
		2:
			obstacles = [Vector2i(4, 2), Vector2i(6, 4), Vector2i(3, 4), Vector2i(7, 2), Vector2i(5, 6)]
		3:
			obstacles = [Vector2i(4, 1), Vector2i(6, 5), Vector2i(5, 3), Vector2i(3, 3), Vector2i(7, 3)]
		_:
			obstacles = [Vector2i(3, 2), Vector2i(7, 4), Vector2i(5, 5), Vector2i(4, 1)]
	
	# 1. Setup Player Stacks (support up to 5 stacks from army / split slots)
	var player_army = GameState.player_army
	var player_hexes = [
		Vector2i(0, 1),
		Vector2i(0, 2),
		Vector2i(0, 3),
		Vector2i(0, 4),
		Vector2i(0, 5)
	]
	for i in range(min(player_army.size(), player_hexes.size())):
		var item = player_army[i]
		if item["count"] > 0:
			var stack = BattleStack.new()
			stack.setup(item["unit_id"], item["count"], 0, player_hexes[i])
			all_stacks.append(stack)
		
	# 2. Setup Enemy Stacks (based on chapter & encounter type)
	var enemy_configs = []
	if GameState.pending_battle_id == "bandit_boss":
		enemy_configs = [
			{"unit_id": "goblin", "count": 35, "hex": Vector2i(10, 1)},
			{"unit_id": "wolf", "count": 18, "hex": Vector2i(10, 3)},
			{"unit_id": "treant", "count": 5, "hex": Vector2i(10, 5)}
		]
		log_combat("Логово Главаря Разбойников! Атаман и его приспешники идут в атаку!")
	elif GameState.pending_battle_id == "lich_boss":
		enemy_configs = [
			{"unit_id": "skeleton_archer", "count": 32, "hex": Vector2i(10, 1)},
			{"unit_id": "swamp_zombie", "count": 22, "hex": Vector2i(10, 3)},
			{"unit_id": "lich", "count": 8, "hex": Vector2i(10, 5)}
		]
		log_combat("Цитадель Тьмы! Древний Лич поднимает нежить из болотных могил!")
	elif GameState.pending_battle_id == "dragon_boss":
		enemy_configs = [
			{"unit_id": "wolf", "count": 25, "hex": Vector2i(10, 1)},
			{"unit_id": "red_dragon", "count": 3, "hex": Vector2i(10, 3)},
			{"unit_id": "treant", "count": 8, "hex": Vector2i(10, 5)}
		]
		log_combat("Гнездо Владыки Огня! Красный Дракон расправляет пылающие крылья!")
	# Chapter 1 Specific Encounters
	elif GameState.pending_battle_id == "patrol_1":
		enemy_configs = [
			{"unit_id": "goblin", "count": 25, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 12, "hex": Vector2i(10, 4)}
		]
		log_combat("Авангард разбойников преграждает дорогу за Железными Вратами!")
	elif GameState.pending_battle_id == "patrol_wolves":
		enemy_configs = [
			{"unit_id": "wolf", "count": 16, "hex": Vector2i(10, 3)}
		]
		log_combat("Стая голодных лесных волков скалит клыки и идет на перехват!")
	elif GameState.pending_battle_id == "patrol_goblins":
		enemy_configs = [
			{"unit_id": "goblin", "count": 24, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 6, "hex": Vector2i(10, 4)}
		]
		log_combat("Шайка гоблинов-грабителей бросается в атаку!")
	elif GameState.pending_battle_id == "patrol_forester":
		enemy_configs = [
			{"unit_id": "goblin", "count": 18, "hex": Vector2i(10, 1)},
			{"unit_id": "wolf", "count": 8, "hex": Vector2i(10, 4)}
		]
		log_combat("Засада разбойников на южном тракте атакует из кустов!")
	elif GameState.pending_battle_id == "patrol_grove":
		enemy_configs = [
			{"unit_id": "treant", "count": 3, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 10, "hex": Vector2i(10, 4)}
		]
		log_combat("Страж Рощи — могучий Древень и его свита пробудились!")
	elif GameState.pending_battle_id == "patrol_rogues":
		enemy_configs = [
			{"unit_id": "goblin", "count": 26, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 14, "hex": Vector2i(10, 4)}
		]
		log_combat("Стрелки разбойников преграждают путь к Роще Фей!")
	elif GameState.pending_battle_id == "patrol_obelisk":
		enemy_configs = [
			{"unit_id": "treant", "count": 3, "hex": Vector2i(10, 1)},
			{"unit_id": "goblin", "count": 20, "hex": Vector2i(10, 3)},
			{"unit_id": "wolf", "count": 10, "hex": Vector2i(10, 5)}
		]
		log_combat("Элитная стража Обелиска защищает древние сокровища!")
	# Chapter 2 Specific Encounters
	elif GameState.pending_battle_id == "swamp_patrol_road":
		enemy_configs = [
			{"unit_id": "swamp_zombie", "count": 18, "hex": Vector2i(10, 3)}
		]
		log_combat("Орда болотных зомби медленно поднимается из тины!")
	elif GameState.pending_battle_id == "swamp_patrol_fens":
		enemy_configs = [
			{"unit_id": "skeleton_archer", "count": 20, "hex": Vector2i(10, 2)}
		]
		log_combat("Скелеты-лучники натягивают тетиву среди камышей!")
	elif GameState.pending_battle_id == "swamp_patrol_gate":
		enemy_configs = [
			{"unit_id": "skeleton_archer", "count": 22, "hex": Vector2i(10, 1)},
			{"unit_id": "swamp_zombie", "count": 14, "hex": Vector2i(10, 4)}
		]
		log_combat("Костяная стража охраняет подступы к Некрополю!")
	elif GameState.pending_battle_id == "swamp_patrol_east":
		enemy_configs = [
			{"unit_id": "skeleton_archer", "count": 24, "hex": Vector2i(10, 2)},
			{"unit_id": "swamp_zombie", "count": 18, "hex": Vector2i(10, 4)}
		]
		log_combat("Легион Смерти преграждает дорогу к Алтарю Друидов!")
	elif GameState.pending_battle_id == "swamp_patrol_ruins":
		enemy_configs = [
			{"unit_id": "lich", "count": 4, "hex": Vector2i(10, 1)},
			{"unit_id": "skeleton_archer", "count": 20, "hex": Vector2i(10, 3)},
			{"unit_id": "swamp_zombie", "count": 12, "hex": Vector2i(10, 5)}
		]
		log_combat("Осквернители древних гробниц обрушивают темную магию!")
	# Chapter 3 Specific Encounters
	elif GameState.pending_battle_id in ["dragon_patrol_pass", "dragon_patrol", "patrol_dragon"]:
		enemy_configs = [
			{"unit_id": "skeleton_archer", "count": 20, "hex": Vector2i(10, 1)},
			{"unit_id": "griffin", "count": 8, "hex": Vector2i(10, 4)}
		]
		log_combat("Огненная стража перевала атакует!")
	elif GameState.pending_battle_id == "dragon_patrol_gate":
		enemy_configs = [
			{"unit_id": "skeleton_archer", "count": 22, "hex": Vector2i(10, 1)},
			{"unit_id": "goblin", "count": 25, "hex": Vector2i(10, 3)},
			{"unit_id": "wolf", "count": 14, "hex": Vector2i(10, 5)}
		]
		log_combat("Стража Огненных Врат идет на таран!")
	elif GameState.pending_battle_id == "dragon_patrol_caldera":
		enemy_configs = [
			{"unit_id": "goblin", "count": 25, "hex": Vector2i(10, 1)},
			{"unit_id": "wolf", "count": 16, "hex": Vector2i(10, 3)},
			{"unit_id": "treant", "count": 4, "hex": Vector2i(10, 5)}
		]
		log_combat("Слуги дракона перекрывают путь к жерлу вулкана!")
	elif GameState.pending_battle_id == "dragon_patrol_citadel":
		enemy_configs = [
			{"unit_id": "griffin", "count": 12, "hex": Vector2i(10, 2)},
			{"unit_id": "goblin", "count": 22, "hex": Vector2i(10, 4)}
		]
		log_combat("Лавовые хищники бросаются на защиту цитадели!")
	elif GameState.pending_battle_id in ["swamp_patrol", "patrol_swamp"]:
		enemy_configs = [
			{"unit_id": "skeleton_archer", "count": 18, "hex": Vector2i(10, 2)},
			{"unit_id": "swamp_zombie", "count": 14, "hex": Vector2i(10, 4)}
		]
		log_combat("Болотная нежить преграждает путь сквозь трясину!")
	elif GameState.pending_battle_id == "patrol_2":
		enemy_configs = [
			{"unit_id": "goblin", "count": 22, "hex": Vector2i(10, 2)},
			{"unit_id": "wolf", "count": 12, "hex": Vector2i(10, 4)}
		]
		log_combat("Вражеский дозор пытается перерезать дорогу!")
	else:
		# Chapter-scaled standard encounter
		if GameState.current_chapter == 2:
			enemy_configs = [
				{"unit_id": "skeleton_archer", "count": 16, "hex": Vector2i(10, 1)},
				{"unit_id": "swamp_zombie", "count": 12, "hex": Vector2i(10, 3)},
				{"unit_id": "wolf", "count": 10, "hex": Vector2i(10, 5)}
			]
			log_combat("Орда нежити восстает из могил болот!")
		elif GameState.current_chapter == 3:
			enemy_configs = [
				{"unit_id": "goblin", "count": 25, "hex": Vector2i(10, 1)},
				{"unit_id": "wolf", "count": 16, "hex": Vector2i(10, 3)},
				{"unit_id": "treant", "count": 4, "hex": Vector2i(10, 5)}
			]
			log_combat("Стражи вулканического ущелья бросаются в бой!")
		else:
			enemy_configs = [
				{"unit_id": "goblin", "count": 18, "hex": Vector2i(10, 1)},
				{"unit_id": "wolf", "count": 9, "hex": Vector2i(10, 3)},
				{"unit_id": "treant", "count": 2, "hex": Vector2i(10, 5)}
			]
			log_combat("Лесные разбойники преграждают путь! Битва началась!")

	for cfg in enemy_configs:
		var stack = BattleStack.new()
		stack.setup(cfg["unit_id"], cfg["count"], 1, cfg["hex"])
		all_stacks.append(stack)

func _start_round() -> void:
	hero_cast_this_round = false
	round_label.text = "Раунд %d" % current_round
	
	for stack in all_stacks:
		if stack.is_alive():
			stack.reset_round()
			
	_rebuild_turn_queue()
	_next_turn()

func _rebuild_turn_queue() -> void:
	turn_queue.clear()
	for stack in all_stacks:
		if stack.is_alive() and not stack.has_acted:
			turn_queue.append(stack)
			
	# Sort descending by initiative
	turn_queue.sort_custom(func(a, b): return a.get_initiative() > b.get_initiative())
	_update_initiative_bar()

func _next_turn() -> void:
	hovered_target = null
	hovered_is_broken = false
	hovered_forecast.clear()
	
	if _check_battle_end():
		return
		
	# Purge dead units from turn_queue
	while not turn_queue.is_empty() and not turn_queue[0].is_alive():
		turn_queue.pop_front()
		
	if turn_queue.is_empty():
		current_round += 1
		_start_round()
		return
		
	current_actor = turn_queue.pop_front()
	if current_actor == null or not current_actor.is_alive():
		_next_turn()
		return
		
	# Check Blind debuff (cannot act while blinded)
	if current_actor.is_blinded():
		_spawn_floating_text(current_actor.hex, "💤 ОСЛЕПЛЕН", Color(1.0, 0.9, 0.3))
		log_combat("✨ %s ослеплен и пропускает ход!" % current_actor.data.name)
		current_actor.has_acted = true
		_update_initiative_bar()
		arena_viewport.queue_redraw()
		await get_tree().create_timer(0.3).timeout
		_next_turn()
		return
		
	_update_initiative_bar()
	_update_reachable_hexes()
	arena_viewport.queue_redraw()
	
	if current_actor.team == 1:
		# AI Turn
		is_ai_turn = true
		_handle_ai_turn()
	else:
		# Player Turn
		is_ai_turn = false
		
		# Start of turn Morale check for living units
		if not current_actor.had_morale_this_round and not current_actor.has_waited and not (current_actor.unit_id in ["skeleton_archer", "swamp_zombie", "lich"]):
			var m_chance = 0.12 + 0.05 * GameState.get_skill_level("leadership")
			if randf() < m_chance:
				SoundManager.play_sfx("spell_cast")
				_spawn_floating_text(current_actor.hex, "🌟 БОДРОСТЬ!", Color(1.0, 0.88, 0.2))
				log_combat("🌟 [БОЕВОЙ ДУХ]: Воодушевленный отряд %s полон решимости сокрушать врагов!" % current_actor.data.name)
				
		if wait_btn:
			wait_btn.disabled = current_actor.has_waited
			if current_actor.has_waited:
				wait_btn.text = "⏳ Ждал"
				wait_btn.tooltip_text = "Отряд уже ждал в этом раунде и обязан действовать!"
			else:
				wait_btn.text = "⏳ Ждать"
				wait_btn.tooltip_text = "Отложить действие до конца раунда (клавиша W)"
		var wait_hint = " (Уже ждал)" if current_actor.has_waited else ""
		log_combat("Ход отряда: %s (%d воинов). [W - Ждать%s, D - Защита, A - Авто, B - Магия]" % [
			current_actor.data.name, current_actor.count, wait_hint
		])
		if is_auto_battling:
			_execute_auto_turn_for_player()

func _update_reachable_hexes() -> void:
	reachable_hexes.clear()
	attackable_targets.clear()
	
	if current_actor == null:
		return
		
	if current_actor.data.get("flying", false):
		# Flying units ignore ground obstacles and can land anywhere reachable that is unblocked
		for r in range(field_bounds.position.y, field_bounds.end.y):
			for q in range(field_bounds.position.x, field_bounds.end.x):
				var h = Vector2i(q, r)
				if h == current_actor.hex or obstacles.has(h):
					continue
				var is_occ = false
				for s in all_stacks:
					if s.is_alive() and s != current_actor and s.hex == h:
						is_occ = true
						break
				if not is_occ and HexGrid.distance(current_actor.hex, h) <= current_actor.get_speed():
					reachable_hexes.append(h)
	else:
		var occupied: Array[Vector2i] = obstacles.duplicate()
		for s in all_stacks:
			if s.is_alive() and s != current_actor:
				occupied.append(s.hex)
				
		reachable_hexes = HexGrid.get_reachable_hexes(
			current_actor.hex, current_actor.get_speed(), occupied, field_bounds
		)
	
	# Find attackable targets
	var is_shooter = current_actor.data.get("is_ranged", false)
	var is_blocked = is_shooter and current_actor.is_blocked_by_enemy(all_stacks)
	for s in all_stacks:
		if s.is_alive() and s.team != current_actor.team:
			if is_shooter and not is_blocked:
				attackable_targets.append(s)
			else:
				# Melee: can attack if adjacent to start or adjacent to any reachable hex
				if HexGrid.distance(current_actor.hex, s.hex) == 1:
					attackable_targets.append(s)
				else:
					for r_hex in reachable_hexes:
						if HexGrid.distance(r_hex, s.hex) == 1:
							if not attackable_targets.has(s):
								attackable_targets.append(s)
								break

func _select_ai_target(actor: BattleStack, player_stacks: Array[BattleStack]) -> BattleStack:
	var best_target: BattleStack = null
	var best_score: float = -999999.0
	
	for target in player_stacks:
		var dist = HexGrid.distance(actor.hex, target.hex)
		var is_ranged: bool = target.data.get("is_ranged", false)
		
		# Tactical threat score (HoMM3 priority logic)
		var score: float = 100.0
		
		# Archers are #1 priority! Eliminate ranged damage and force melee penalty!
		if is_ranged:
			score += 260.0
			
		# Kill bonus: prioritize stacks that will suffer high casualties
		var est_dmg = actor.calculate_attack_damage(target, true)
		var target_hp = target.data.get("max_hp", 20)
		var cas = mini(target.count, int(est_dmg / target_hp))
		score += cas * 30.0
		
		# Safe attack bonus if target already retaliated
		if target.has_retaliated:
			score += 35.0
			
		# Distance cost
		score -= dist * 20.0
		
		# If adjacent right now, bonus for instant strike
		if dist == 1:
			score += 70.0
			
		if score > best_score:
			best_score = score
			best_target = target
			
	return best_target

func _handle_ai_turn() -> void:
	await get_tree().create_timer(0.5).timeout
	if not current_actor or not current_actor.is_alive():
		_next_turn()
		return
		
	# Find player stacks
	var targets: Array[BattleStack] = []
	for s in all_stacks:
		if s.is_alive() and s.team == 0:
			targets.append(s)
			
	if targets.is_empty():
		_check_battle_end()
		return
		
	var target = _select_ai_target(current_actor, targets)
	if target == null:
		target = targets[0]
	
	# If ranged and not blocked by adjacent enemy, attack immediately at range
	if current_actor.data.get("is_ranged", false) and not current_actor.is_blocked_by_enemy(all_stacks):
		_execute_attack(current_actor, target, false)
		return
	
	# If adjacent, attack directly
	if HexGrid.distance(current_actor.hex, target.hex) == 1:
		_execute_attack(current_actor, target, true)
		return
		
	# Otherwise find best reachable hex closest to target
	var best_hex = current_actor.hex
	var best_dist = HexGrid.distance(current_actor.hex, target.hex)
	
	for h in reachable_hexes:
		var d = HexGrid.distance(h, target.hex)
		if d < best_dist:
			best_dist = d
			best_hex = h
			
	if best_hex != current_actor.hex:
		current_actor.hex = best_hex
		arena_viewport.queue_redraw()
		await get_tree().create_timer(0.35).timeout
		
	# Check if now adjacent after move
	if HexGrid.distance(current_actor.hex, target.hex) == 1:
		_execute_attack(current_actor, target, true)
	else:
		current_actor.has_acted = true
		_next_turn()

func _execute_attack(attacker: BattleStack, defender: BattleStack, is_melee: bool) -> void:
	is_animating = true
	var start_pos = HexGrid.hex_to_pixel(attacker.hex.x, attacker.hex.y, HEX_SIZE, grid_origin)
	var end_pos = HexGrid.hex_to_pixel(defender.hex.x, defender.hex.y, HEX_SIZE, grid_origin)
	
	if not is_melee:
		# Ranged Attack
		var dist = HexGrid.distance(attacker.hex, defender.hex)
		var is_broken = (dist > 5)
		SoundManager.play_sfx("bow_shot")
		
		# Attacker slight recoil
		var recoil_dir = (start_pos - end_pos).normalized() * 12.0
		var r_tw = create_tween()
		r_tw.tween_method(func(val: Vector2): arena_viewport.set_stack_offset(attacker, val), Vector2.ZERO, recoil_dir, 0.1).set_trans(Tween.TRANS_QUAD)
		r_tw.tween_method(func(val: Vector2): arena_viewport.set_stack_offset(attacker, val), recoil_dir, Vector2.ZERO, 0.15).set_trans(Tween.TRANS_QUAD)
		
		var is_lucky = (attacker.team == 0 and randf() < 0.15)
		var arrow1_hit = false
		arena_viewport.spawn_arrow(start_pos, end_pos, func():
			SoundManager.play_sfx("arrow_hit")
			arena_viewport.flash_stack(defender)
			var dmg = attacker.calculate_attack_damage(defender, false, is_broken)
			if is_lucky:
				dmg = int(dmg * 2.0)
				_spawn_floating_text(attacker.hex, "🍀 УДАЧА! (х2)", Color(0.3, 1.0, 0.4))
				log_combat("🍀 [УДАЧА]: Отряд %s совершает выстрел с удвоенным критическим уроном!" % attacker.data.name)
			var res = defender.take_damage(dmg)
			_spawn_floating_text(defender.hex, "-%d" % res.damage, Color(1.0, 0.3, 0.2))
			if res.casualties > 0:
				_spawn_floating_text(defender.hex, "Потери: -%d" % res.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
			if res.get("dispelled_blind", false):
				_spawn_floating_text(defender.hex, "ПРОЗРЕНИЕ!", Color(0.9, 0.9, 1.0), Vector2(0, -45))
			if is_broken:
				log_combat("⚡ Сломанная стрела! %s наносит %d урона (штраф 50%%) по %s! (Потери: %d)" % [
					attacker.data.name, res.damage, defender.data.name, res.casualties
				])
			else:
				log_combat("🎯 Прямой выстрел! %s поражает %s на %d урона! (Потери: %d)" % [
					attacker.data.name, defender.data.name, res.damage, res.casualties
				])
			arena_viewport.queue_redraw()
			arrow1_hit = true
			_check_battle_end()
		)
		
		var wait_t = 0.0
		while not arrow1_hit and wait_t < 1.0:
			await get_tree().process_frame
			wait_t += get_process_delta_time()
		await get_tree().create_timer(0.2).timeout
		
		if _check_battle_end():
			is_animating = false
			attacker.has_acted = true
			return
		
		if attacker.data.get("double_shot", false) and defender.is_alive() and _has_living_enemies():
			var arrow2_hit = false
			SoundManager.play_sfx("bow_shot")
			arena_viewport.spawn_arrow(start_pos, end_pos, func():
				SoundManager.play_sfx("arrow_hit")
				arena_viewport.flash_stack(defender)
				var dmg2 = attacker.calculate_attack_damage(defender, false, is_broken)
				if is_lucky:
					dmg2 = int(dmg2 * 2.0)
				var res2 = defender.take_damage(dmg2)
				_spawn_floating_text(defender.hex, "-%d" % res2.damage, Color(1.0, 0.45, 0.2))
				if res2.casualties > 0:
					_spawn_floating_text(defender.hex, "Потери: -%d" % res2.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
				if res2.get("dispelled_blind", false):
					_spawn_floating_text(defender.hex, "ПРОЗРЕНИЕ!", Color(0.9, 0.9, 1.0), Vector2(0, -45))
				log_combat("🏹 Второй выстрел! %s наносит %d урона по %s! (Потери: %d)" % [
					attacker.data.name, res2.damage, defender.data.name, res2.casualties
				])
				arena_viewport.queue_redraw()
				arrow2_hit = true
				_check_battle_end()
			)
			var wait_t2 = 0.0
			while not arrow2_hit and wait_t2 < 1.0:
				await get_tree().process_frame
				wait_t2 += get_process_delta_time()
			await get_tree().create_timer(0.2).timeout
			
		is_animating = false
		attacker.has_acted = true
		
		if _check_battle_end():
			return
			
		# Morale check for shooters (only if battle still has active enemies)
		if attacker.is_alive() and attacker.team == 0 and not attacker.had_morale_this_round and _has_living_enemies():
			var m_chance = 0.05 + 0.10 * GameState.get_skill_level("leadership")
			if randf() < m_chance:
				attacker.had_morale_this_round = true
				attacker.has_acted = false
				SoundManager.play_sfx("spell_cast")
				_spawn_floating_text(attacker.hex, "🌟 БОЕВОЙ ДУХ! (+1 ХОД)", Color(1.0, 0.88, 0.2))
				log_combat("🌟 [БОЕВОЙ ДУХ]: Воодушевленный отряд %s получает дополнительный ход!" % attacker.data.name)
				_update_initiative_bar()
				_update_reachable_hexes()
				arena_viewport.queue_redraw()
				return
		_next_turn()
		return

	# Melee Attack: Lunge forward towards defender
	var is_melee_lucky = (attacker.team == 0 and randf() < 0.15)
	var lunge_vec = (end_pos - start_pos).normalized() * 32.0
	var tw = create_tween()
	tw.tween_method(func(val: Vector2): arena_viewport.set_stack_offset(attacker, val), Vector2.ZERO, lunge_vec, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		SoundManager.play_sfx("sword_hit")
		arena_viewport.flash_stack(defender)
		var dmg = attacker.calculate_attack_damage(defender, true)
		if is_melee_lucky:
			dmg = int(dmg * 2.0)
			_spawn_floating_text(attacker.hex, "🍀 УДАЧА! (х2)", Color(0.3, 1.0, 0.4))
			log_combat("🍀 [УДАЧА]: Отряд %s наносит удвоенный сокрушительный урон!" % attacker.data.name)
		var res = defender.take_damage(dmg)
		_spawn_floating_text(defender.hex, "-%d" % res.damage, Color(1.0, 0.3, 0.2))
		if res.casualties > 0:
			_spawn_floating_text(defender.hex, "Потери: -%d" % res.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
		if res.get("dispelled_blind", false):
			_spawn_floating_text(defender.hex, "ПРОЗРЕНИЕ!", Color(0.9, 0.9, 1.0), Vector2(0, -45))
		log_combat("%s атакует %s и наносит %d урона! (Потери: %d)" % [
			attacker.data.name, defender.data.name, res.damage, res.casualties
		])
		
		# Dragon 2-hex linear breath attack
		if (attacker.data.get("breath_attack", false) or attacker.unit_id == "red_dragon") and _has_living_enemies():
			var delta_h = defender.hex - attacker.hex
			var behind_hex = defender.hex + delta_h
			if HexGrid.is_in_bounds(behind_hex, field_bounds):
				var behind_stack: BattleStack = null
				for s in all_stacks:
					if s.is_alive() and s.hex == behind_hex and s != defender and s != attacker:
						behind_stack = s
						break
				if behind_stack != null:
					var b_dmg = int(dmg * 0.8)
					var b_res = behind_stack.take_damage(b_dmg)
					arena_viewport.flash_stack(behind_stack)
					_spawn_floating_text(behind_hex, "🔥 -%d" % b_res.damage, Color(1.0, 0.45, 0.1))
					if b_res.casualties > 0:
						_spawn_floating_text(behind_hex, "Потери: -%d" % b_res.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
					log_combat("🔥 [ОГНЕННОЕ ДЫХАНИЕ]: Струя пламени пробивает строй и поражает %s на %d урона! (Потери: %d)" % [
						behind_stack.data.name, b_res.damage, b_res.casualties
					])
		
		# Creature Passives: Zombie Disease & Treant Entangle
		if defender.is_alive():
			if attacker.data.get("disease", false) or attacker.unit_id == "swamp_zombie":
				defender.debuff_disease_turns = 2
				_spawn_floating_text(defender.hex, "☣ БОЛЕЗНЬ! (-25% АТАКИ)", Color(0.5, 0.9, 0.2), Vector2(0, -48))
				log_combat("☣ Трупный яд заражает %s: атака снижена на 25%% на 2 раунда!" % defender.data.name)
			elif (attacker.data.get("entangle", false) or attacker.unit_id == "treant") and randf() < 0.35:
				defender.debuff_entangle_turns = 1
				_spawn_floating_text(defender.hex, "🌿 КОРНИ (0 ХОДОВ)", Color(0.2, 0.85, 0.3), Vector2(0, -48))
				log_combat("🌿 Корни древня оплетают %s, лишая возможности двигаться на 1 раунд!" % defender.data.name)
		
		arena_viewport.queue_redraw()
		_check_battle_end()
	)
	tw.tween_method(func(val: Vector2): arena_viewport.set_stack_offset(attacker, val), lunge_vec, Vector2.ZERO, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	arena_viewport.set_stack_offset(attacker, Vector2.ZERO)
	
	if _check_battle_end():
		is_animating = false
		attacker.has_acted = true
		return
		
	# Retaliation
	if defender.is_alive() and (not defender.has_retaliated or defender.data.get("unlimited_retaliation", false)) and _has_living_enemies():
		defender.has_retaliated = true
		await get_tree().create_timer(0.2).timeout
		var ret_lunge = (start_pos - end_pos).normalized() * 28.0
		var rtw = create_tween()
		rtw.tween_method(func(val: Vector2): arena_viewport.set_stack_offset(defender, val), Vector2.ZERO, ret_lunge, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rtw.tween_callback(func():
			SoundManager.play_sfx("sword_hit")
			arena_viewport.flash_stack(attacker)
			var ret_dmg = defender.calculate_attack_damage(attacker, true)
			var ret_res = attacker.take_damage(ret_dmg)
			_spawn_floating_text(attacker.hex, "-%d" % ret_dmg, Color(1.0, 0.5, 0.3))
			if ret_res.casualties > 0:
				_spawn_floating_text(attacker.hex, "Потери: -%d" % ret_res.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
			if ret_res.get("dispelled_blind", false):
				_spawn_floating_text(attacker.hex, "ПРОЗРЕНИЕ!", Color(0.9, 0.9, 1.0), Vector2(0, -45))
			log_combat("  Ответный удар: %s наносит %d урона! (Потери: %d)" % [
				defender.data.name, ret_dmg, ret_res.casualties
			])
			arena_viewport.queue_redraw()
			_check_battle_end()
		)
		rtw.tween_method(func(val: Vector2): arena_viewport.set_stack_offset(defender, val), ret_lunge, Vector2.ZERO, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await rtw.finished
		arena_viewport.set_stack_offset(defender, Vector2.ZERO)
		
	is_animating = false
	attacker.has_acted = true
	
	if _check_battle_end():
		return
		
	# Morale check for melee fighters (only if battle still has active enemies)
	if attacker.is_alive() and attacker.team == 0 and not attacker.had_morale_this_round and _has_living_enemies():
		var m_chance = 0.05 + 0.10 * GameState.get_skill_level("leadership")
		if randf() < m_chance:
			attacker.had_morale_this_round = true
			attacker.has_acted = false
			SoundManager.play_sfx("spell_cast")
			_spawn_floating_text(attacker.hex, "🌟 БОЕВОЙ ДУХ! (+1 ХОД)", Color(1.0, 0.88, 0.2))
			log_combat("🌟 [БОЕВОЙ ДУХ]: Воодушевленный отряд %s получает дополнительный ход!" % attacker.data.name)
			_update_initiative_bar()
			_update_reachable_hexes()
			arena_viewport.queue_redraw()
			return
			
	await get_tree().create_timer(0.3).timeout
	_next_turn()

func _execute_spell(spell_id: String, target_stack: BattleStack) -> void:
	var spell = SpellData.get_spell(spell_id)
	var cost: int = spell.get("mana_cost", 10)
	var spell_type: String = spell.get("type", "target_enemy")
	
	# Validate target
	if spell_type == "target_enemy" and target_stack.team != 1:
		log_combat("Заклинание %s можно применить только к вражескому отряду!" % spell.name)
		return
	elif spell_type == "target_ally" and target_stack.team != 0:
		log_combat("Заклинание %s можно применить только к союзному отряду!" % spell.name)
		return
		
	if not GameState.spend_mana(cost):
		log_combat("Недостаточно маны для сотворения заклинания!")
		return
		
	hero_cast_this_round = true
	pending_spell_id = ""
	_update_ui()
	
	is_animating = true
	
	match spell_id:
		"fireball":
			SoundManager.play_sfx("spell_cast")
			var start_p = Vector2(grid_origin.x - 120, grid_origin.y + 120)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			var fb_hit = false
			arena_viewport.spawn_fireball(start_p, end_p, func():
				SoundManager.play_sfx("arrow_hit")
				arena_viewport.flash_stack(target_stack)
				var cur_sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
				var dmg = 50 + cur_sp * 14
				if GameState.has_skill("sorcery"):
					dmg = int(dmg * 1.25)
				var res = target_stack.take_damage(dmg)
				_spawn_floating_text(target_stack.hex, "ОГОНЬ -%d" % res.damage, Color(1.0, 0.4, 0.1))
				log_combat("Аларик сокрушает %s Огненным Шаром! Урон: %d (Потери: %d)" % [
					target_stack.data.name, res.damage, res.casualties
				])
				arena_viewport.queue_redraw()
				fb_hit = true
				_check_battle_end()
			)
			var fb_wait = 0.0
			while not fb_hit and fb_wait < 1.0:
				await get_tree().process_frame
				fb_wait += get_process_delta_time()
		"heal":
			SoundManager.play_sfx("spell_cast")
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(0.3, 1.0, 0.5))
			arena_viewport.flash_stack(target_stack)
			var cur_sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
			var heal_amount = 60 + cur_sp * 16
			target_stack.heal(heal_amount)
			_spawn_floating_text(target_stack.hex, "+%d HP" % heal_amount, Color(0.3, 1.0, 0.4))
			log_combat("Исцеление: отряд %s восстанавливает %d ед. здоровья!" % [
				target_stack.data.name, heal_amount
			])
		"bless":
			SoundManager.play_sfx("spell_cast")
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(1.0, 0.9, 0.3))
			arena_viewport.flash_stack(target_stack)
			target_stack.buff_bless_turns = 3
			_spawn_floating_text(target_stack.hex, "БЛАГОСЛОВЕНИЕ!", Color(1.0, 0.9, 0.3))
			log_combat("%s благословлен святым сиянием на 3 раунда!" % target_stack.data.name)
		"haste":
			SoundManager.play_sfx("spell_cast")
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(0.4, 0.8, 1.0))
			arena_viewport.flash_stack(target_stack)
			target_stack.buff_haste_turns = 3
			_spawn_floating_text(target_stack.hex, "УСКОРЕНИЕ!", Color(0.4, 0.8, 1.0))
			log_combat("%s получает ускорение (+3 к скорости)!" % target_stack.data.name)
		"lightning":
			SoundManager.play_sfx("spell_cast")
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			var lt_hit = false
			arena_viewport.spawn_lightning(end_p, func():
				SoundManager.play_sfx("sword_hit")
				arena_viewport.flash_stack(target_stack)
				var cur_sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
				var dmg = 65 + cur_sp * 18
				if GameState.has_skill("sorcery"):
					dmg = int(dmg * 1.25)
				var res = target_stack.take_damage(dmg)
				_spawn_floating_text(target_stack.hex, "МОЛНИЯ -%d" % res.damage, Color(0.85, 0.95, 1.0))
				log_combat("Небесная Молния поражает %s на %d урона! (Потери: %d)" % [
					target_stack.data.name, res.damage, res.casualties
				])
				arena_viewport.queue_redraw()
				lt_hit = true
				_check_battle_end()
			)
			var lt_wait = 0.0
			while not lt_hit and lt_wait < 1.0:
				await get_tree().process_frame
				lt_wait += get_process_delta_time()
		"slow":
			SoundManager.play_sfx("spell_cast")
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_frost(end_p, func():
				arena_viewport.flash_stack(target_stack)
				target_stack.buff_slow_turns = 3
				_spawn_floating_text(target_stack.hex, "ЗАМЕДЛЕНИЕ!", Color(0.4, 0.85, 1.0))
				log_combat("%s скован леденящим инеем (скорость снижена на 50%% на 3 раунда)!" % target_stack.data.name)
				arena_viewport.queue_redraw()
				_update_reachable_hexes()
			)
		"stoneskin":
			SoundManager.play_sfx("spell_cast")
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_stoneskin(end_p, func():
				arena_viewport.flash_stack(target_stack)
				target_stack.buff_stoneskin_turns = 3
				_spawn_floating_text(target_stack.hex, "КАМЕННАЯ КОЖА (+5)", Color(0.85, 0.75, 0.5))
				log_combat("%s покрыт каменной броней (+5 к Защите на 3 раунда)!" % target_stack.data.name)
				arena_viewport.queue_redraw()
				_update_reachable_hexes()
			)
		"blind":
			SoundManager.play_sfx("spell_cast")
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_blind(end_p, func():
				arena_viewport.flash_stack(target_stack)
				target_stack.debuff_blind_turns = 3
				_spawn_floating_text(target_stack.hex, "ОСЛЕПЛЕНИЕ!", Color(1.0, 0.95, 0.4))
				log_combat("%s ослеплен яркой вспышкой и не может действовать!" % target_stack.data.name)
				arena_viewport.queue_redraw()
				_update_reachable_hexes()
			)
			
	is_animating = false
	arena_viewport.queue_redraw()
	_update_reachable_hexes()
	_check_battle_end()

func _find_stack_at_position(click_pos: Vector2) -> BattleStack:
	for s in all_stacks:
		if not s.is_alive():
			continue
		var s_center = HexGrid.hex_to_pixel(s.hex.x, s.hex.y, HEX_SIZE, grid_origin)
		var bottom_y = s_center.y + HEX_SIZE * 0.45
		var top_y = bottom_y - HEX_SIZE * 2.2
		var sprite_rect = Rect2(s_center.x - 55, top_y, 110, HEX_SIZE * 2.2)
		if sprite_rect.has_point(click_pos) or click_pos.distance_to(s_center) < HEX_SIZE * 0.85:
			return s
	return null

func _has_living_enemies() -> bool:
	for s in all_stacks:
		if s.is_alive() and s.team == 1:
			return true
	return false

func _has_living_players() -> bool:
	for s in all_stacks:
		if s.is_alive() and s.team == 0:
			return true
	return false

func _check_battle_end() -> bool:
	if victory_dialog.visible:
		return true
	var players_alive := _has_living_players()
	var enemies_alive := _has_living_enemies()
				
	if not enemies_alive:
		_show_victory(true)
		return true
	elif not players_alive:
		_show_victory(false)
		return true
	return false

func _show_victory(won: bool) -> void:
	if victory_dialog.visible:
		return
	is_animating = false
	is_ai_turn = false
	current_actor = null
	turn_queue.clear()
	reachable_hexes.clear()
	attackable_targets.clear()
	hovered_target = null
	arena_viewport.queue_redraw()
	victory_dialog.move_to_front()
	victory_dialog.show()
	if won:
		SoundManager.play_sfx("victory")
		victory_title.text = "СЛАВНАЯ ПОБЕДА!"
		if GameState.is_demo_battle:
			victory_desc.text = "🏆 Тренировочный поединок на Арене успешно завершен!\nСложность: %s\nПротивник: %s\n\nВы продемонстрировали выдающееся тактическое мастерство полководца!" % [
				GameState.demo_difficulty_title, GameState.demo_encounter_title
			]
			return
		var reward_gold = 750
		var reward_xp = 550
		if GameState.pending_battle_id == "bandit_boss":
			reward_gold = 1500
			reward_xp = 1200
			GameState.has_fairy_crown = true
			if not GameState.inventory_artifacts.has("crown_fairy") and not GameState.equipped_artifacts.values().has("crown_fairy"):
				GameState.inventory_artifacts.append("crown_fairy")
			victory_desc.text = "Главарь разбойников повержен!\n\n★ ВЫ ВЕРНУЛИ ВЕНЕЦ КОРОЛЕВЫ ФЕЙ! ★\nПолучен легендарный артефакт: Венец Королевы Фей!\nОтнесите его в Рощу Фей на севере!\n\nНаграда:\nЗолото: +%d\nОпыт: +%d" % [reward_gold, reward_xp]
		elif GameState.pending_battle_id == "lich_boss":
			reward_gold = 2500
			reward_xp = 2200
			GameState.flags["lich_defeated"] = true
			if not GameState.inventory_artifacts.has("ring_arcana") and not GameState.equipped_artifacts.values().has("ring_arcana"):
				GameState.inventory_artifacts.append("ring_arcana")
			victory_desc.text = "Древний Лич сокрушен и обращен в прах!\n\n★ ПРОКЛЯТЫЕ ТОПИ ОЧИЩЕНЫ! ★\nПолучен могущественный артефакт: Перстень Архимага!\nПосетите Алтарь Друидов для завершения Главы 2!\n\nНаграда:\nЗолото: +%d\nОпыт: +%d" % [reward_gold, reward_xp]
		elif GameState.pending_battle_id == "dragon_boss":
			reward_gold = 5000
			reward_xp = 4000
			GameState.flags["dragon_defeated"] = true
			if not GameState.inventory_artifacts.has("armor_chitin") and not GameState.equipped_artifacts.values().has("armor_chitin"):
				GameState.inventory_artifacts.append("armor_chitin")
			victory_desc.text = "Красный Дракон повержен в легендарном поединке!\n\n★ ТРИУМФ НАД ПЛАМЕНЕМ! ★\nПолучен легендарный Панцирь Древнего Стража!\nВы покорили Пик Дракона и спасли Королевство!\n\nНаграда:\nЗолото: +%d\nОпыт: +%d" % [reward_gold, reward_xp]
		else:
			victory_desc.text = "Вы рассеяли вражеский отряд!\n\nПолучено награды:\nЗолото: +%d\nОпыт героя: +%d" % [reward_gold, reward_xp]
			
		GameState.add_gold(reward_gold)
		GameState.add_xp(reward_xp)
		
		# Save that enemy on the map is defeated
		if GameState.pending_battle_id != "":
			GameState.flags[GameState.pending_battle_id] = true
			GameState.pending_battle_id = ""
		GameState.save_game()
			
		# Sync remaining stacks back to player_army
		_sync_army_after_battle()
	else:
		SoundManager.play_sfx("click")
		victory_title.text = "ПОРАЖЕНИЕ..."
		if GameState.is_demo_battle:
			victory_desc.text = "Ваши воины пали на Арене!\nСложность: %s\n\nСмените тактику, подберите другой состав отрядов и попробуйте снова!" % GameState.demo_difficulty_title
			return
		victory_desc.text = "Ваши воины были вынуждены отступить.\nВраг остался на своей позиции!\nПерегруппируйтесь и попробуйте снова!"
		# Do NOT clear enemy flag on map!
		GameState.pending_battle_id = ""
		
		# Give minimal reinforcements so player is not stuck with 0 units
		var total_alive = 0
		for s in all_stacks:
			if s.team == 0 and s.is_alive():
				total_alive += s.count
		if total_alive == 0:
			GameState.player_army = [
				{"unit_id": "fairy_archer", "count": 6},
				{"unit_id": "griffin", "count": 2}
			]
			GameState.state_changed.emit()

func _sync_army_after_battle() -> void:
	if GameState.is_demo_battle:
		return
	var updated_army: Array[Dictionary] = []
	for s in all_stacks:
		if s.team == 0 and s.is_alive() and s.count > 0:
			updated_army.append({"unit_id": s.unit_id, "count": s.count})
	if updated_army.size() > 0:
		GameState.player_army = updated_army
		GameState.state_changed.emit()

func _on_victory_continue() -> void:
	SoundManager.play_sfx("click")
	var is_demo = GameState.is_demo_battle
	var target = GameState.battle_return_scene if GameState.battle_return_scene != "" else "res://src/world/world_map.tscn"
	if is_demo or target == "res://src/main.tscn":
		GameState.is_demo_battle = false
		var pref = SoundManager.load_music_preference()
		var theme_to_play = pref if pref != "" else "res://assets/audio/music/themes/homm2_01_sorceress_garden.wav"
		SoundManager.play_music(theme_to_play)
		get_tree().change_scene_to_file("res://src/main.tscn")
		return
	get_tree().change_scene_to_file(target)

func _on_defend_pressed() -> void:
	if is_ai_turn or is_animating or current_actor == null or current_actor.team != 0:
		return
	SoundManager.play_sfx("click")
	current_actor.is_defending = true
	current_actor.has_acted = true
	log_combat("%s встает в глухую оборону (+30%% к защите)!" % current_actor.data.name)
	_next_turn()

func _on_wait_pressed() -> void:
	if is_ai_turn or is_animating or current_actor == null or current_actor.team != 0:
		return
	if current_actor.has_waited:
		log_combat("⚠️ Отряд %s уже выжидал в этом раунде и обязан действовать!" % current_actor.data.name)
		return
	SoundManager.play_sfx("click")
	current_actor.has_waited = true
	turn_queue.append(current_actor)
	current_actor = null
	log_combat("⏳ Отряд выжидает удобного момента...")
	_next_turn()

func _toggle_auto_battle() -> void:
	is_auto_battling = not is_auto_battling
	SoundManager.play_sfx("click")
	if is_auto_battling:
		if auto_battle_btn:
			auto_battle_btn.text = "🛑 Стоп"
			auto_battle_btn.modulate = Color(1.0, 0.45, 0.45)
		log_combat("⚡ Режим автобоя ВКЛЮЧЕН!")
		if not is_ai_turn and not is_animating and current_actor != null and current_actor.team == 0:
			_execute_auto_turn_for_player()
	else:
		if auto_battle_btn:
			auto_battle_btn.text = "⚡ Авто"
			auto_battle_btn.modulate = Color.WHITE
		log_combat("Режим автобоя выключен. Ручное управление.")

func _execute_auto_turn_for_player() -> void:
	if current_actor == null or not current_actor.is_alive() or current_actor.team != 0:
		return
	await get_tree().create_timer(0.2).timeout
	if not is_auto_battling or current_actor == null or not current_actor.is_alive():
		return
		
	var enemies: Array[BattleStack] = []
	for s in all_stacks:
		if s.is_alive() and s.team == 1:
			enemies.append(s)
	if enemies.is_empty():
		return
		
	var target = _select_ai_target(current_actor, enemies)
	if target == null:
		current_actor.has_acted = true
		_next_turn()
		return
		
	var is_shooter = current_actor.data.get("is_ranged", false)
	var is_blocked = is_shooter and current_actor.is_blocked_by_enemy(all_stacks)
	if is_shooter and not is_blocked:
		_execute_attack(current_actor, target, false)
		return
		
	var best_hex = current_actor.hex
	var best_dist = HexGrid.distance(current_actor.hex, target.hex)
	var valid_moves = reachable_hexes.duplicate()
	valid_moves.append(current_actor.hex)
	
	for h in valid_moves:
		var d = HexGrid.distance(h, target.hex)
		if d == 1:
			best_hex = h
			break
		if d < best_dist:
			best_dist = d
			best_hex = h
			
	if best_hex != current_actor.hex:
		current_actor.hex = best_hex
		arena_viewport.queue_redraw()
		await get_tree().create_timer(0.2).timeout
		
	if HexGrid.distance(current_actor.hex, target.hex) == 1:
		_execute_attack(current_actor, target, true)
	else:
		current_actor.has_acted = true
		_next_turn()

func _on_spellbook_btn_pressed() -> void:
	if is_ai_turn or is_animating:
		return
	SoundManager.play_sfx("page_turn")
	spellbook_dialog.visible = not spellbook_dialog.visible

func _setup_spell_buttons() -> void:
	var container = $CanvasLayer/SpellbookDialog/Parchment/SpellGrid
	for child in container.get_children():
		child.queue_free()
		
	for spell_id in GameState.learned_spells:
		var sdata = SpellData.get_spell(spell_id)
		if sdata.get("category", "combat") != "combat":
			continue
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(sdata.icon_path):
			btn.texture_normal = load(sdata.icon_path)
		btn.tooltip_text = "%s (%d маны)\n%s" % [sdata.name, sdata.mana_cost, sdata.description]
		btn.pressed.connect(func(): _on_spell_selected(spell_id))
		container.add_child(btn)

func _on_spell_selected(spell_id: String) -> void:
	var sdata = SpellData.get_spell(spell_id)
	if GameState.current_mana < sdata.mana_cost:
		log_combat("Не хватает маны на заклинание %s!" % sdata.name)
		return
	if hero_cast_this_round:
		log_combat("Герой уже сотворил заклинание в этом раунде!")
		return
		
	SoundManager.play_sfx("click")
	pending_spell_id = spell_id
	spellbook_dialog.hide()
	log_combat("Выберите цель для заклинания: %s (ПКМ/Esc для отмены)" % sdata.name)
	arena_viewport.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				if current_actor and current_actor.team == 0 and current_actor.has_waited:
					log_combat("⚠️ Отряд %s уже ждал в этом раунде и обязан действовать!" % current_actor.data.name)
				else:
					_on_wait_pressed()
			KEY_D, KEY_SPACE:
				_on_defend_pressed()
			KEY_A:
				_toggle_auto_battle()
			KEY_B, KEY_S:
				_on_spellbook_btn_pressed()
			KEY_R:
				_on_retreat_pressed()
			KEY_ESCAPE:
				if pending_spell_id != "":
					pending_spell_id = ""
					log_combat("Сотворение заклинания отменено.")
					arena_viewport.queue_redraw()
				elif spellbook_dialog.visible:
					spellbook_dialog.hide()
				elif unit_info_dialog.visible:
					unit_info_dialog.hide()

func _gui_input(event: InputEvent) -> void:
	if is_ai_turn or is_animating or current_actor == null or current_actor.team != 0:
		return
		
	# Mouse Motion -> Real-time damage forecast and broken arrow detection
	if event is InputEventMouseMotion:
		_update_mouse_hover(event.position)
		
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if pending_spell_id != "":
				pending_spell_id = ""
				log_combat("Сотворение заклинания отменено.")
				arena_viewport.queue_redraw()
				return
				
			var clicked = _find_stack_at_position(event.position)
			if clicked != null:
				_show_unit_info(clicked)
				return
				
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				touch_down_time = Time.get_ticks_msec() / 1000.0
				touch_down_pos = event.position
				touch_candidate = _find_stack_at_position(event.position)
			else:
				var held_time = (Time.get_ticks_msec() / 1000.0) - touch_down_time
				if held_time >= 0.38 and touch_candidate != null and event.position.distance_to(touch_down_pos) < 30.0:
					_show_unit_info(touch_candidate)
					touch_candidate = null
					return
				touch_candidate = null
				
				# 1. Spell Targeting
				if pending_spell_id != "":
					var clicked_target = _find_stack_at_position(event.position)
					if clicked_target != null:
						_execute_spell(pending_spell_id, clicked_target)
						return
					var hex = HexGrid.pixel_to_hex(event.position, HEX_SIZE, grid_origin)
					for s in all_stacks:
						if s.is_alive() and s.hex == hex:
							_execute_spell(pending_spell_id, s)
							return
					return
					
				# 2. Attack Detection (Clicking on enemy stack sprite or hex)
				var clicked_stack = _find_stack_at_position(event.position)
				if clicked_stack != null:
					if attackable_targets.has(clicked_stack):
						_handle_player_attack(clicked_stack)
						return
					else:
						# Direct tap on non-attackable stack (ally or distant enemy) opens Unit Inspector
						_show_unit_info(clicked_stack)
						return
					
				var hex = HexGrid.pixel_to_hex(event.position, HEX_SIZE, grid_origin)
				for target in attackable_targets:
					if target.hex == hex:
						_handle_player_attack(target)
						return
						
				# 3. Move Detection (Clicking on empty reachable hex)
				if reachable_hexes.has(hex):
					var is_occ = false
					for s in all_stacks:
						if s.is_alive() and s.hex == hex:
							is_occ = true
							break
					if not is_occ:
						SoundManager.play_sfx("click")
						current_actor.hex = hex
						current_actor.has_acted = true
						_next_turn()

func _update_mouse_hover(pos: Vector2) -> void:
	if current_actor == null or current_actor.team != 0:
		return
	var stack = _find_stack_at_position(pos)
	
	# Threat Range preview on hovering enemy stack
	var threat_stack = stack
	if threat_stack == null:
		var hovered_hex = HexGrid.pixel_to_hex(pos, HEX_SIZE, grid_origin)
		for s in all_stacks:
			if s.is_alive() and s.hex == hovered_hex:
				threat_stack = s
				break
	if threat_stack != null and threat_stack.is_alive() and threat_stack.team == 1:
		var threats: Array[Vector2i] = []
		var spd = threat_stack.get_speed()
		var reach = HexGrid.get_reachable_hexes(threat_stack.hex, spd, obstacles, field_bounds)
		reach.append(threat_stack.hex)
		if threat_stack.data.get("is_ranged", false):
			for r in range(field_bounds.position.y, field_bounds.end.y):
				for q in range(field_bounds.position.x, field_bounds.end.x):
					var h = Vector2i(q, r)
					if not obstacles.has(h):
						threats.append(h)
		else:
			for rh in reach:
				if not threats.has(rh):
					threats.append(rh)
				for n in HexGrid.get_neighbors(rh):
					if HexGrid.is_in_bounds(n, field_bounds) and not obstacles.has(n) and not threats.has(n):
						threats.append(n)
		hovered_threat_hexes = threats
	else:
		hovered_threat_hexes.clear()
		
	if stack != null and attackable_targets.has(stack):
		hovered_target = stack
		var is_shooter = current_actor.data.get("is_ranged", false)
		var is_blocked = is_shooter and current_actor.is_blocked_by_enemy(all_stacks)
		var dist = HexGrid.distance(current_actor.hex, stack.hex)
		var is_melee_attack = (dist == 1) or not is_shooter or is_blocked
		var is_broken = is_shooter and not is_melee_attack and (dist > 5)
		hovered_is_broken = is_broken
		hovered_forecast = current_actor.get_damage_range(stack, is_melee_attack, is_broken)
		
		# Detailed HoMM3-style combat forecast in log
		if is_shooter and not is_melee_attack:
			if is_broken:
				log_combat("⚡ [СЛОМАННАЯ СТРЕЛА! Дистанция %d > 5, Штраф -50%%]: Урон %d-%d (Потери: %d-%d)" % [
					dist, hovered_forecast.min_dmg, hovered_forecast.max_dmg, hovered_forecast.min_cas, hovered_forecast.max_cas
				])
			else:
				log_combat("🏹 [ПРЯМОЙ ВЫСТРЕЛ: Дистанция %d]: Урон %d-%d (Потери: %d-%d)" % [
					dist, hovered_forecast.min_dmg, hovered_forecast.max_dmg, hovered_forecast.min_cas, hovered_forecast.max_cas
				])
		elif is_shooter and is_melee_attack:
			var can_ret = (not stack.has_retaliated or stack.data.get("unlimited_retaliation", false))
			log_combat("⚔ [РУКОПАШНАЯ (СТРЕЛОК В УПОР, ШТРАФ -50%%)]: Урон %d-%d (Потери: %d-%d)%s" % [
				hovered_forecast.min_dmg, hovered_forecast.max_dmg, hovered_forecast.min_cas, hovered_forecast.max_cas,
				" [Враг ответит!]" if can_ret else " [Без ответа]"
			])
		else:
			var can_ret = (not stack.has_retaliated or stack.data.get("unlimited_retaliation", false))
			log_combat("⚔ [РУКОПАШНАЯ АТАКА]: Урон %d-%d (Потери: %d-%d)%s" % [
				hovered_forecast.min_dmg, hovered_forecast.max_dmg, hovered_forecast.min_cas, hovered_forecast.max_cas,
				" [Враг ответит!]" if can_ret else " [Без ответа]"
			])
		arena_viewport.queue_redraw()
	else:
		if hovered_target != null:
			hovered_target = null
			hovered_is_broken = false
			hovered_forecast.clear()
		arena_viewport.queue_redraw()

func _show_unit_info(stack: BattleStack) -> void:
	SoundManager.play_sfx("page_turn")
	var t_path = stack.data.get("token_path", "")
	if ResourceLoader.exists(t_path):
		unit_info_portrait.texture = load(t_path)
		
	var team_name = "Ваше войско" if stack.team == 0 else "Вражеский отряд"
	var max_hp = stack.data.get("max_hp", 20)
	var total_pool = (stack.count - 1) * max_hp + stack.current_hp
	
	var traits = []
	if stack.data.get("is_ranged", false):
		traits.append("Стрелок (дальность 5 гексов)")
	if stack.data.get("unlimited_retaliation", false):
		traits.append("Бесконечный отпор")
	if stack.data.get("breath_attack", false) or stack.unit_id == "red_dragon":
		traits.append("Огненное дыхание (пробивает насквозь)")
	if stack.data.get("disease", false) or stack.unit_id == "swamp_zombie":
		traits.append("Трупный яд (ослабляет атаку)")
	if stack.data.get("regeneration", 0) > 0 or stack.unit_id == "treant":
		traits.append("Регенерация (+20 HP в раунд)")
	if stack.data.get("entangle", false) or stack.unit_id == "treant":
		traits.append("Оплетающие корни")
	if traits.is_empty():
		traits.append("Обычные боевые навыки")
		
	var buffs = []
	if stack.buff_bless_turns > 0:
		buffs.append("Благословение (%d р.)" % stack.buff_bless_turns)
	if stack.buff_haste_turns > 0:
		buffs.append("Ускорение (%d р.)" % stack.buff_haste_turns)
	if stack.buff_stoneskin_turns > 0:
		buffs.append("Каменная кожа (+5 защ., %d р.)" % stack.buff_stoneskin_turns)
	if stack.debuff_blind_turns > 0:
		buffs.append("Ослепление (%d р.)" % stack.debuff_blind_turns)
	if stack.debuff_disease_turns > 0:
		buffs.append("Болезнь (-25%% атк., %d р.)" % stack.debuff_disease_turns)
	if stack.debuff_entangle_turns > 0:
		buffs.append("Опутан корнями (0 скор.)")
	if stack.is_defending:
		buffs.append("Глухая оборона (+30% защ.)")
	var buffs_str = ", ".join(buffs) if buffs.size() > 0 else "Нет"
	
	unit_info_stats.text = "%s (%s)\nЧисленность: %d воинов\nЗдоровье верхнего воина: %d / %d HP\nВсего здоровья отряда: %d HP\n\nАтака: %d | Защита: %d\nУрон: %d-%d\nСкорость: %d | Инициатива: %d\n\nОсобенности: %s\nАктивные эффекты: %s" % [
		stack.data.name, team_name, stack.count,
		stack.current_hp, max_hp, total_pool,
		stack.data.get("attack", 4), stack.get_defense(),
		stack.data.get("min_dmg", 3), stack.data.get("max_dmg", 6),
		stack.get_speed(), stack.get_initiative(),
		", ".join(traits), buffs_str
	]
	
	unit_info_dialog.show()

func _handle_player_attack(target: BattleStack) -> void:
	var is_shooter = current_actor.data.get("is_ranged", false)
	var is_blocked = is_shooter and current_actor.is_blocked_by_enemy(all_stacks)
	var dist = HexGrid.distance(current_actor.hex, target.hex)
	var is_melee = (dist == 1) or not is_shooter or is_blocked
	if not is_melee:
		_execute_attack(current_actor, target, false)
	else:
		# Melee: move adjacent if not already adjacent
		if HexGrid.distance(current_actor.hex, target.hex) > 1:
			for r_hex in reachable_hexes:
				if HexGrid.distance(r_hex, target.hex) == 1:
					current_actor.hex = r_hex
					break
		_execute_attack(current_actor, target, true)

func _update_initiative_bar() -> void:
	for child in initiative_container.get_children():
		child.queue_free()
		
	var display_list: Array[BattleStack] = []
	if current_actor != null and current_actor.is_alive():
		display_list.append(current_actor)
	for s in turn_queue:
		if s.is_alive() and not display_list.has(s):
			display_list.append(s)
			
	for i in range(display_list.size()):
		var stack = display_list[i]
		var is_cur = (i == 0 and stack == current_actor)
		
		var panel = PanelContainer.new()
		var pstyle = StyleBoxFlat.new()
		pstyle.set_corner_radius_all(6)
		pstyle.border_width_left = 3 if is_cur else 2
		pstyle.border_width_right = 3 if is_cur else 2
		pstyle.border_width_top = 3 if is_cur else 2
		pstyle.border_width_bottom = 3 if is_cur else 2
		if is_cur:
			pstyle.border_color = Color(1.0, 0.85, 0.2) # Golden border for current
			pstyle.bg_color = Color(0.2, 0.16, 0.05, 0.9)
		elif stack.team == 0:
			pstyle.border_color = Color(0.2, 0.8, 0.3) # Green for allies
			pstyle.bg_color = Color(0.08, 0.18, 0.08, 0.85)
		else:
			pstyle.border_color = Color(0.9, 0.25, 0.25) # Red for enemies
			pstyle.bg_color = Color(0.2, 0.06, 0.06, 0.85)
		panel.add_theme_stylebox_override("panel", pstyle)
		
		var inner = Control.new()
		inner.custom_minimum_size = Vector2(54, 54) if is_cur else Vector2(46, 46)
		panel.add_child(inner)
		
		var token = TextureRect.new()
		token.anchors_preset = Control.PRESET_FULL_RECT
		token.anchor_right = 1.0
		token.anchor_bottom = 1.0
		token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path = stack.data.get("token_path", "")
		if ResourceLoader.exists(icon_path):
			token.texture = load(icon_path)
		inner.add_child(token)
		
		var count_lbl = Label.new()
		count_lbl.text = str(stack.count)
		count_lbl.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		count_lbl.anchor_left = 1.0
		count_lbl.anchor_top = 1.0
		count_lbl.anchor_right = 1.0
		count_lbl.anchor_bottom = 1.0
		count_lbl.offset_left = -30
		count_lbl.offset_top = -18
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		count_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
		inner.add_child(count_lbl)
		
		initiative_container.add_child(panel)

func _update_ui() -> void:
	hero_mana_label.text = "Мана: %d / %d" % [GameState.current_mana, GameState.max_mana]
	hero_mana_bar.max_value = GameState.max_mana
	hero_mana_bar.value = GameState.current_mana

func log_combat(msg: String) -> void:
	log_label.text = msg

func _spawn_floating_text(hex: Vector2i, text: String, color: Color, custom_offset: Vector2 = Vector2.ZERO) -> void:
	var pos = HexGrid.hex_to_pixel(hex.x, hex.y, HEX_SIZE, grid_origin)
	floating_texts.append({
		"pos": pos + Vector2(0, -30) + custom_offset,
		"text": text,
		"color": color,
		"alpha": 1.0,
		"time": 0.0
	})

func _process(delta: float) -> void:
	var to_remove = []
	for item in floating_texts:
		item.time += delta
		item.pos.y -= delta * 35.0
		item.alpha = maxf(0.0, 1.0 - (item.time / 1.2))
		if item.time >= 1.2:
			to_remove.append(item)
	for r in to_remove:
		floating_texts.erase(r)
	if floating_texts.size() > 0:
		arena_viewport.queue_redraw()
