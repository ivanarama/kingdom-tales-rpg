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
var pending_attack_target: BattleStack = null # тач: первый тап показывает прогноз

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
var is_fast_forward: bool = false
var speed_btn: Button
var enemy_spell_charges: int = 0 # сколько раз Лич может колдовать за бой
var army_start_snapshot: Array[Dictionary] = [] # численность на начало боя (для fallen_units)
var _army_counts: Dictionary = {} # BattleStack игрока -> численность в войске до масштаба сложности
var battle_stats: Dictionary = {}

# Rewards scale with defeated enemy strength (computed at battle start)
var pending_reward_gold: int = 0
var pending_reward_xp: int = 0

# Combat log history (newest last) + transient hover-forecast line
var log_history: Array[String] = []
var _live_log_line: String = ""
var retreat_confirm_dialog: Control
var auto_battle_btn: Button
var defend_btn: Button
var wait_btn: Button
var retreat_btn: Button
var boss: BossMechanics # способности боссов: знамя Атамана, подъём нежити, огненный шквал

const BATTLE_MUSIC := "res://assets/audio/music/battle_theme.ogg"
## Бои с боссами — под свою тему из музыкальной шкатулки, остальные — под общую боевую.
const BOSS_BATTLE_MUSIC := {
	"bandit_boss": "res://assets/audio/music/themes/theme_15_battle_call.ogg",
	"lich_boss": "res://assets/audio/music/themes/homm2_03_warlock_dungeon.ogg",
	"dragon_boss": "res://assets/audio/music/themes/theme_17_dragon_peak.ogg",
}

static func battle_music_for(battle_id: String) -> String:
	return BOSS_BATTLE_MUSIC.get(battle_id, BATTLE_MUSIC)
const FIREBALL_SPLASH := 0.5 # доля урона огненного шара по соседним с целью вражеским отрядам

## Раскладки препятствий по главам (пни, надгробия, обсидиан). Первая — прежняя.
## Колонки 0 и 10 — места расстановки войск, поэтому препятствия только в 2..8.
const OBSTACLE_LAYOUTS := {
	1: [
		[Vector2i(3, 2), Vector2i(7, 4), Vector2i(5, 5), Vector2i(4, 1)],
		[Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 4), Vector2i(3, 5), Vector2i(7, 1)],
		[Vector2i(2, 3), Vector2i(5, 3), Vector2i(8, 3), Vector2i(4, 5), Vector2i(6, 1)],
	],
	2: [
		[Vector2i(4, 2), Vector2i(6, 4), Vector2i(3, 4), Vector2i(7, 2), Vector2i(5, 6)],
		[Vector2i(3, 1), Vector2i(5, 3), Vector2i(7, 5), Vector2i(4, 5), Vector2i(6, 1)],
		[Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(3, 6), Vector2i(7, 0)],
	],
	3: [
		[Vector2i(4, 1), Vector2i(6, 5), Vector2i(5, 3), Vector2i(3, 3), Vector2i(7, 3)],
		[Vector2i(3, 2), Vector2i(4, 4), Vector2i(6, 2), Vector2i(7, 4), Vector2i(5, 6)],
		[Vector2i(5, 1), Vector2i(5, 2), Vector2i(4, 4), Vector2i(6, 4), Vector2i(2, 5), Vector2i(8, 1)],
	],
}
## Поля боссов: частокол у лагеря Атамана, полукруг могил в склепе Лича, скалы у кратера.
const BOSS_OBSTACLES := {
	"bandit_boss": [Vector2i(7, 1), Vector2i(7, 2), Vector2i(8, 4), Vector2i(8, 5), Vector2i(4, 3)],
	"lich_boss": [Vector2i(6, 1), Vector2i(5, 2), Vector2i(4, 4), Vector2i(5, 5), Vector2i(7, 5)],
	"dragon_boss": [Vector2i(4, 2), Vector2i(6, 1), Vector2i(7, 3), Vector2i(6, 5), Vector2i(3, 5)],
}

## Препятствия боя: у босса своя раскладка, у остальных — одна из раскладок главы,
## выбранная по id встречи (одна и та же встреча всегда выглядит одинаково).
static func obstacle_layout(battle_id: String, chapter: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if BOSS_OBSTACLES.has(battle_id):
		result.assign(BOSS_OBSTACLES[battle_id])
		return result
	var layouts: Array = OBSTACLE_LAYOUTS.get(chapter, OBSTACLE_LAYOUTS[1])
	var idx := 0 if battle_id == "" else absi(battle_id.hash()) % layouts.size()
	result.assign(layouts[idx])
	return result

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _ready() -> void:
	SoundManager.play_music(battle_music_for(GameState.pending_battle_id))
	_init_battle()
	BattleMood.apply_for_battle($Background, all_stacks) # топи и вулкан — своим настроением
	log_combat("🍀 Удача: 15% шанс двойного урона у вашего войска. 🌟 Боевой дух даёт доп. ход (Лидерство).")
	var fortune := GameState.get_enemy_fortune(_battle_difficulty())
	if float(fortune["luck"]) > 0.0:
		log_combat(tr("⚠ На этой сложности удача (%d%%) и боевой дух (%d%%) бывают и у врага.") % [
			int(round(float(fortune["luck"]) * 100.0)), int(round(float(fortune["morale"]) * 100.0))
		])
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

	# Ускорение боя x2 (для длинных сражений)
	speed_btn = Button.new()
	speed_btn.name = "SpeedBtn"
	speed_btn.text = "⏩ x2"
	speed_btn.offset_left = 378.0
	speed_btn.offset_right = 466.0
	speed_btn.offset_top = defend_btn.offset_top
	speed_btn.offset_bottom = defend_btn.offset_bottom
	speed_btn.add_theme_font_size_override("font_size", 16)
	speed_btn.pressed.connect(_toggle_fast_forward)
	$CanvasLayer/HeroHUD/Parchment.add_child(speed_btn)

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
	_build_retreat_confirm_dialog()
	
	_setup_spell_buttons()
	# Первый бой кампании — с подсказками (один раз)
	if BattleTutorial.should_show():
		var tutorial := BattleTutorial.new()
		$CanvasLayer.add_child(tutorial)
		tutorial.setup(self)
	_update_ui()
	_start_round()

func _on_retreat_pressed() -> void:
	SoundManager.play_sfx("click")
	if GameState.is_demo_battle:
		GameState.is_demo_battle = false
		var pref = SoundManager.load_music_preference()
		var theme_to_play = pref if pref != "" else "res://assets/audio/music/themes/homm2_01_sorceress_garden.ogg"
		SoundManager.play_music(theme_to_play)
		get_tree().change_scene_to_file("res://src/main.tscn")
	elif retreat_confirm_dialog != null:
		retreat_confirm_dialog.move_to_front()
		retreat_confirm_dialog.show()
	else:
		_show_victory(false)


func _build_retreat_confirm_dialog() -> void:
	retreat_confirm_dialog = Control.new()
	retreat_confirm_dialog.name = "RetreatConfirmDialog"
	retreat_confirm_dialog.visible = false
	retreat_confirm_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			retreat_confirm_dialog.hide()
	)
	retreat_confirm_dialog.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	retreat_confirm_dialog.add_child(center)

	var parch = NinePatchRect.new()
	parch.texture = load("res://assets/art/ui/parchment_panel.png")
	parch.patch_margin_left = 24
	parch.patch_margin_top = 24
	parch.patch_margin_right = 24
	parch.patch_margin_bottom = 24
	parch.custom_minimum_size = Vector2(560, 280)
	center.add_child(parch)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 28
	vbox.offset_right = -28
	vbox.offset_top = 24
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 14)
	parch.add_child(vbox)

	var title = Label.new()
	title.text = "Отступить из боя?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "Враг останется на своей позиции,\nи вы сможете атаковать его снова.\nПобеда пока не одержана."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.22, 0.14, 0.06))
	vbox.add_child(desc)

	var btns = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	vbox.add_child(btns)

	var yes_btn = Button.new()
	yes_btn.text = "🏳️ Да, отступить"
	yes_btn.custom_minimum_size = Vector2(210, 54)
	yes_btn.add_theme_font_size_override("font_size", 16)
	yes_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		retreat_confirm_dialog.hide()
		_show_victory(false)
	)
	btns.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.text = "⚔️ Остаться в бою"
	no_btn.custom_minimum_size = Vector2(210, 54)
	no_btn.add_theme_font_size_override("font_size", 16)
	no_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		retreat_confirm_dialog.hide()
	)
	btns.add_child(no_btn)

	$CanvasLayer.add_child(retreat_confirm_dialog)

func _init_battle() -> void:
	all_stacks.clear()
	obstacles.clear()
	boss = BossMechanics.new(self)
	
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
			
		battle_stats = {"rounds": 1, "dealt": 0, "taken": 0, "enemy_losses": 0, "player_losses": 0}
		enemy_spell_charges = 0
		log_combat(tr("⚔️ Демонстрационный бой [%s]: %s!") % [GameState.demo_difficulty_title, GameState.demo_encounter_title])
		return

	# Препятствия: у главы несколько раскладок, у боссов — свои
	obstacles = obstacle_layout(GameState.pending_battle_id, GameState.current_chapter)
	
	# 1. Setup Player Stacks (support up to 5 stacks from army / split slots)
	var player_army = GameState.player_army
	var player_hexes = [
		Vector2i(0, 1),
		Vector2i(0, 2),
		Vector2i(0, 3),
		Vector2i(0, 4),
		Vector2i(0, 5)
	]
	army_start_snapshot.clear()
	for item in player_army:
		if item["count"] > 0:
			army_start_snapshot.append({"unit_id": str(item["unit_id"]), "count": int(item["count"])})
	var diff := GameState.get_difficulty_multipliers(GameState.campaign_difficulty)
	for i in range(min(player_army.size(), player_hexes.size())):
		var item = player_army[i]
		if item["count"] > 0:
			var stack = BattleStack.new()
			stack.setup(item["unit_id"], maxi(1, int(round(item["count"] * float(diff["player"])))), 0, player_hexes[i])
			all_stacks.append(stack)
			_army_counts[stack] = int(item["count"])
		
	# 2. Setup Enemy Stacks (data-driven: data/encounters.json)
	var enemy_configs := []
	var enc := EncounterData.get_encounter(GameState.pending_battle_id)
	if enc.is_empty():
		enc = EncounterData.get_default_for_chapter(GameState.current_chapter)
	if not enc["log"].is_empty():
		log_combat(tr(enc["log"]))
	enemy_configs = enc["enemies"]

	for cfg in enemy_configs:
		var stack = BattleStack.new()
		stack.setup(cfg["unit_id"], maxi(1, int(round(cfg["count"] * float(diff["enemy"])))), 1, cfg["hex"])
		all_stacks.append(stack)

	# Rewards scale with enemy strength (tier & headcount); bosses override in _show_victory
	pending_reward_gold = 100
	pending_reward_xp = 60
	for s in all_stacks:
		if s.team == 1:
			pending_reward_gold += s.count * 12 + int(s.data.get("tier", 1)) * 10
			pending_reward_xp += s.count * 8 + int(s.data.get("tier", 1)) * 12

	battle_stats = {"rounds": 1, "dealt": 0, "taken": 0, "enemy_losses": 0, "player_losses": 0}
	enemy_spell_charges = 0
	for s in all_stacks:
		if s.team == 1 and s.data.get("is_caster", false):
			enemy_spell_charges += mini(3, 1 + int(s.count / 3.0))
	if GameState.has_artifact_effect("horn_of_valor"):
		for s in all_stacks:
			if s.team == 0:
				s.init_bonus = 2
		log_combat("📯 Рог Доблести: всё войско начинает бой на +2 инициативы!")

func _start_round() -> void:
	hero_cast_this_round = false
	round_label.text = tr("Раунд %d") % current_round
	battle_stats["rounds"] = current_round
	
	for stack in all_stacks:
		if stack.is_alive():
			stack.reset_round()
	boss.on_round_start()
			
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
	boss.before_turn()
	hovered_target = null
	hovered_is_broken = false
	hovered_forecast.clear()
	pending_attack_target = null
	
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
		log_combat(tr("✨ %s ослеплен и пропускает ход!") % tr(current_actor.data.name))
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
		
		if wait_btn:
			wait_btn.disabled = current_actor.has_waited
			if current_actor.has_waited:
				wait_btn.text = "⏳ Ждал"
				wait_btn.tooltip_text = "Отряд уже ждал в этом раунде и обязан действовать!"
			else:
				wait_btn.text = "⏳ Ждать"
				wait_btn.tooltip_text = "Отложить действие до конца раунда (клавиша W)"
		var wait_hint = " (Уже ждал)" if current_actor.has_waited else ""
		var fire_hint := boss.turn_hint(current_actor)
		if fire_hint != "":
			log_combat(fire_hint)
		else:
			log_combat(tr("Ход отряда: %s (%d воинов). [W - Ждать%s, D - Защита, A - Авто, B - Магия]") % [
				tr(current_actor.data.name), current_actor.count, wait_hint
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
		# (средний урон вместо случайного броска — выбор цели не «дрожит» от хода к ходу)
		var melee: bool = not actor.data.get("is_ranged", false) or actor.is_blocked_by_enemy(all_stacks)
		var hit := actor.get_damage_range(target, melee, not melee and dist > 5)
		var est_dmg: float = (hit["min_dmg"] + hit["max_dmg"]) * 0.5
		var target_hp = target.data.get("max_hp", 20)
		var cas = mini(target.count, int(est_dmg / target_hp))
		score += cas * 30.0

		# Ответный удар: в ближнем бою выжившие ответят — дорогая цель хуже дешёвой
		if melee and (not target.has_retaliated or target.data.get("unlimited_retaliation", false)):
			var survivors: int = target.count - cas
			if survivors > 0:
				var ret := target.get_damage_range(actor, true)
				var ret_dmg: float = (ret["min_dmg"] + ret["max_dmg"]) * 0.5 * float(survivors) / float(target.count)
				var my_losses := mini(actor.count, int(ret_dmg / float(actor.data.get("max_hp", 20))))
				score -= my_losses * 25.0

		# Защита своих стрелков: цель, стоящая вплотную к нашему стрелку, мешает ему стрелять
		for ally in all_stacks:
			if ally != actor and ally.team == actor.team and ally.is_alive() and ally.data.get("is_ranged", false) and HexGrid.distance(ally.hex, target.hex) == 1:
				score += 120.0
				break
		
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
	# Способность босса (вдох или выдох дракона) заменяет обычный ход
	if boss.plan_turn(current_actor):
		var actor := current_actor
		await boss.take_turn(actor)
		actor.has_acted = true
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

	# Колдовство Лича: тёмное пламя по самой густой пачке игрока (с 2-го раунда)
	if enemy_spell_charges > 0 and current_actor.data.get("is_caster", false) and current_round >= 2 and randf() < 0.65:
		enemy_spell_charges -= 1
		_execute_enemy_dark_flame(current_actor)
		return
	
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

## Вражеское заклинание: тёмное пламя (Лич и прочие is_caster).
func _execute_enemy_dark_flame(caster: BattleStack) -> void:
	is_animating = true
	SoundManager.play_spell_sfx("dark_flame")
	var best: BattleStack = null
	var best_pool := -1.0
	for s in all_stacks:
		if s.is_alive() and s.team == 0:
			var pool := float(s.count) * float(s.data.get("max_hp", 20))
			if pool > best_pool:
				best_pool = pool
				best = s
	if best == null:
		is_animating = false
		_next_turn()
		return
	var start_p = HexGrid.hex_to_pixel(caster.hex.x, caster.hex.y, HEX_SIZE, grid_origin)
	var end_p = HexGrid.hex_to_pixel(best.hex.x, best.hex.y, HEX_SIZE, grid_origin)
	log_combat(tr("☠ %s читает заклинание тёмного пламени...") % tr(caster.data.name))
	var hit_done = false
	arena_viewport.spawn_fireball(start_p, end_p, func():
		arena_viewport.flash_stack(best)
		var dmg := 45 + caster.count * 2
		var res: Dictionary = best.take_damage(dmg)
		battle_stats["taken"] += int(res["damage"]) + int(res.get("absorbed", 0))
		battle_stats["player_losses"] += int(res["casualties"])
		_spawn_floating_text(best.hex, tr("☠ ТЬМА -%d") % int(res["damage"]), Color(0.7, 0.3, 0.9))
		log_combat(tr("☠ Тёмное пламя %s поражает %s на %d урона! (Потери: %d)") % [tr(caster.data.name), tr(best.data.name), int(res["damage"]), int(res["casualties"])])
		arena_viewport.queue_redraw()
		hit_done = true
		_check_battle_end()
	)
	var waited = 0.0
	while not hit_done and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	is_animating = false
	caster.has_acted = true
	if _check_battle_end():
		return
	await get_tree().create_timer(0.2).timeout
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
		
		var is_lucky = _roll_luck(attacker)
		var arrow1_hit = false
		arena_viewport.spawn_arrow(start_pos, end_pos, func():
			SoundManager.play_sfx("arrow_hit")
			arena_viewport.flash_stack(defender)
			var dmg = attacker.calculate_attack_damage(defender, false, is_broken)
			if is_lucky:
				dmg = int(dmg * 2.0)
				_spawn_floating_text(attacker.hex, "🍀 УДАЧА! (х2)", Color(0.3, 1.0, 0.4))
				log_combat(tr("🍀 [УДАЧА]: Отряд %s совершает выстрел с удвоенным критическим уроном!") % tr(attacker.data.name))
			var res = _resolve_attack_damage(attacker, defender, dmg, false)
			_spawn_floating_text(defender.hex, tr("-%d") % res.damage, Color(1.0, 0.3, 0.2))
			if res.casualties > 0:
				_spawn_floating_text(defender.hex, tr("Потери: -%d") % res.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
			if res.get("dispelled_blind", false):
				_spawn_floating_text(defender.hex, "ПРОЗРЕНИЕ!", Color(0.9, 0.9, 1.0), Vector2(0, -45))
			if is_broken:
				log_combat(tr("⚡ Сломанная стрела! %s наносит %d урона (штраф 50%%) по %s! (Потери: %d)") % [
					tr(attacker.data.name), res.damage, tr(defender.data.name), res.casualties
				])
			else:
				log_combat(tr("🎯 Прямой выстрел! %s поражает %s на %d урона! (Потери: %d)") % [
					tr(attacker.data.name), tr(defender.data.name), res.damage, res.casualties
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
				var res2 = _resolve_attack_damage(attacker, defender, dmg2, false)
				_spawn_floating_text(defender.hex, tr("-%d") % res2.damage, Color(1.0, 0.45, 0.2))
				if res2.casualties > 0:
					_spawn_floating_text(defender.hex, tr("Потери: -%d") % res2.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
				if res2.get("dispelled_blind", false):
					_spawn_floating_text(defender.hex, "ПРОЗРЕНИЕ!", Color(0.9, 0.9, 1.0), Vector2(0, -45))
				log_combat(tr("🏹 Второй выстрел! %s наносит %d урона по %s! (Потери: %d)") % [
					tr(attacker.data.name), res2.damage, tr(defender.data.name), res2.casualties
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
			
		# Боевой дух стрелков (у врага — только на высокой сложности)
		if _try_morale(attacker):
			return
		_next_turn()
		return

	# Melee Attack: Lunge forward towards defender
	var is_melee_lucky = _roll_luck(attacker)
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
			log_combat(tr("🍀 [УДАЧА]: Отряд %s наносит удвоенный сокрушительный урон!") % tr(attacker.data.name))
		var res = _resolve_attack_damage(attacker, defender, dmg, true)
		_spawn_floating_text(defender.hex, tr("-%d") % res.damage, Color(1.0, 0.3, 0.2))
		if res.casualties > 0:
			_spawn_floating_text(defender.hex, tr("Потери: -%d") % res.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
		if res.get("dispelled_blind", false):
			_spawn_floating_text(defender.hex, "ПРОЗРЕНИЕ!", Color(0.9, 0.9, 1.0), Vector2(0, -45))
		log_combat(tr("%s атакует %s и наносит %d урона! (Потери: %d)") % [
			tr(attacker.data.name), tr(defender.data.name), res.damage, res.casualties
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
					_spawn_floating_text(behind_hex, tr("🔥 -%d") % b_res.damage, Color(1.0, 0.45, 0.1))
					if b_res.casualties > 0:
						_spawn_floating_text(behind_hex, tr("Потери: -%d") % b_res.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
					log_combat(tr("🔥 [ОГНЕННОЕ ДЫХАНИЕ]: Струя пламени пробивает строй и поражает %s на %d урона! (Потери: %d)") % [
						tr(behind_stack.data.name), b_res.damage, b_res.casualties
					])
		
		# Creature Passives: Zombie Disease & Treant Entangle
		if defender.is_alive():
			if attacker.data.get("disease", false) or attacker.unit_id == "swamp_zombie":
				defender.debuff_disease_turns = 2
				if defender.has_acted:
					defender.debuff_disease_turns += 1 # цель походила: эффект продлевается
				_spawn_floating_text(defender.hex, "☣ БОЛЕЗНЬ! (-25% АТАКИ)", Color(0.5, 0.9, 0.2), Vector2(0, -48))
				log_combat(tr("☣ Трупный яд заражает %s: атака снижена на 25%% на 2 раунда!") % tr(defender.data.name))
			elif (attacker.data.get("entangle", false) or attacker.unit_id == "treant") and randf() < 0.35:
				defender.debuff_entangle_turns = 1
				if defender.has_acted:
					defender.debuff_entangle_turns += 1 # цель походила: эффект продлевается
				_spawn_floating_text(defender.hex, "🌿 КОРНИ (0 ХОДОВ)", Color(0.2, 0.85, 0.3), Vector2(0, -48))
				log_combat(tr("🌿 Корни древня оплетают %s, лишая возможности двигаться на 1 раунд!") % tr(defender.data.name))
		
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
			var ret_res = _resolve_attack_damage(defender, attacker, ret_dmg, true)
			_spawn_floating_text(attacker.hex, tr("-%d") % ret_dmg, Color(1.0, 0.5, 0.3))
			if ret_res.casualties > 0:
				_spawn_floating_text(attacker.hex, tr("Потери: -%d") % ret_res.casualties, Color(1.0, 0.1, 0.1), Vector2(0, -28))
			if ret_res.get("dispelled_blind", false):
				_spawn_floating_text(attacker.hex, "ПРОЗРЕНИЕ!", Color(0.9, 0.9, 1.0), Vector2(0, -45))
			log_combat(tr("  Ответный удар: %s наносит %d урона! (Потери: %d)") % [
				tr(defender.data.name), ret_dmg, ret_res.casualties
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
		
	# Боевой дух бойцов ближнего боя (у врага — только на высокой сложности)
	if _try_morale(attacker):
		return
			
	await get_tree().create_timer(0.3).timeout
	_next_turn()

func _execute_spell(spell_id: String, target_stack: BattleStack) -> void:
	var spell = SpellData.get_spell(spell_id)
	var cost: int = spell.get("mana_cost", 10)
	var spell_type: String = spell.get("type", "target_enemy")
	
	# Validate target
	if spell_type == "target_enemy" and target_stack.team != 1:
		log_combat(tr("Заклинание %s можно применить только к вражескому отряду!") % tr(spell.name))
		return
	elif spell_type == "target_ally" and target_stack.team != 0:
		log_combat(tr("Заклинание %s можно применить только к союзному отряду!") % tr(spell.name))
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
			SoundManager.play_spell_sfx(spell_id)
			var start_p = Vector2(grid_origin.x - 120, grid_origin.y + 120)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			var fb_hit = false
			arena_viewport.spawn_fireball(start_p, end_p, func():
				SoundManager.play_sfx("arrow_hit")
				arena_viewport.flash_stack(target_stack)
				var cur_sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
				var dmg = 50 + cur_sp * 14
				dmg = int(dmg * (1.0 + GameState.skill_bonus("sorcery")))
				var res = target_stack.take_damage(dmg)
				if target_stack.team == 1:
					battle_stats["dealt"] += int(res["damage"]) + int(res.get("absorbed", 0))
					battle_stats["enemy_losses"] += int(res["casualties"])
				_spawn_floating_text(target_stack.hex, tr("ОГОНЬ -%d") % res.damage, Color(1.0, 0.4, 0.1))
				log_combat(tr("%s сокрушает %s Огненным Шаром! Урон: %d (Потери: %d)") % [
					tr(GameState.hero_name), tr(target_stack.data.name), res.damage, res.casualties
				])
				# Пламя перекидывается на соседние отряды той же стороны — свои под удар не попадают
				var splash_hits := 0
				for s in all_stacks:
					if s == target_stack or not s.is_alive() or s.team != target_stack.team or HexGrid.distance(s.hex, target_stack.hex) != 1:
						continue
					var sres: Dictionary = s.take_damage(int(dmg * FIREBALL_SPLASH))
					if s.team == 1:
						battle_stats["dealt"] += int(sres["damage"]) + int(sres.get("absorbed", 0))
						battle_stats["enemy_losses"] += int(sres["casualties"])
					arena_viewport.flash_stack(s)
					arena_viewport.spawn_holy_halo(HexGrid.hex_to_pixel(s.hex.x, s.hex.y, HEX_SIZE, grid_origin), Color(1.0, 0.5, 0.1))
					_spawn_floating_text(s.hex, tr("ОГОНЬ -%d") % int(sres["damage"]), Color(1.0, 0.55, 0.15))
					splash_hits += 1
				if splash_hits > 0:
					log_combat(tr("🔥 Пламя перекидывается на соседние отряды: %d") % splash_hits)
				arena_viewport.queue_redraw()
				fb_hit = true
				_check_battle_end()
			)
			var fb_wait = 0.0
			while not fb_hit and fb_wait < 1.0:
				await get_tree().process_frame
				fb_wait += get_process_delta_time()
		"heal":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(0.3, 1.0, 0.5))
			arena_viewport.flash_stack(target_stack)
			var cur_sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
			var heal_amount = 60 + cur_sp * 16
			var heal_res: Dictionary = target_stack.heal(heal_amount)
			var healed: int = int(heal_res["healed"])
			_spawn_floating_text(target_stack.hex, tr("+%d HP") % healed, Color(0.3, 1.0, 0.4))
			log_combat(tr("Исцеление: отряд %s восстанавливает %d ед. здоровья!") % [
				tr(target_stack.data.name), healed
			])
		"bless":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(1.0, 0.9, 0.3))
			arena_viewport.flash_stack(target_stack)
			target_stack.buff_bless_turns = 3
			_spawn_floating_text(target_stack.hex, "БЛАГОСЛОВЕНИЕ!", Color(1.0, 0.9, 0.3))
			log_combat(tr("%s благословлен святым сиянием на 3 раунда!") % tr(target_stack.data.name))
		"haste":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(0.4, 0.8, 1.0))
			arena_viewport.flash_stack(target_stack)
			target_stack.buff_haste_turns = 3
			_spawn_floating_text(target_stack.hex, "УСКОРЕНИЕ!", Color(0.4, 0.8, 1.0))
			log_combat(tr("%s получает ускорение (+3 к скорости)!") % tr(target_stack.data.name))
		"lightning":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			var lt_hit = false
			arena_viewport.spawn_lightning(end_p, func():
				SoundManager.play_sfx("sword_hit")
				arena_viewport.flash_stack(target_stack)
				var cur_sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
				var dmg = 65 + cur_sp * 18
				dmg = int(dmg * (1.0 + GameState.skill_bonus("sorcery")))
				var res = target_stack.take_damage(dmg)
				if target_stack.team == 1:
					battle_stats["dealt"] += int(res["damage"]) + int(res.get("absorbed", 0))
					battle_stats["enemy_losses"] += int(res["casualties"])
				_spawn_floating_text(target_stack.hex, tr("МОЛНИЯ -%d") % res.damage, Color(0.85, 0.95, 1.0))
				log_combat(tr("Небесная Молния поражает %s на %d урона! (Потери: %d)") % [
					tr(target_stack.data.name), res.damage, res.casualties
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
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_frost(end_p, func():
				arena_viewport.flash_stack(target_stack)
				target_stack.buff_slow_turns = 3
				_spawn_floating_text(target_stack.hex, "ЗАМЕДЛЕНИЕ!", Color(0.4, 0.85, 1.0))
				log_combat(tr("%s скован леденящим инеем (скорость снижена на 50%% на 3 раунда)!") % tr(target_stack.data.name))
				arena_viewport.queue_redraw()
				_update_reachable_hexes()
			)
		"stoneskin":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_stoneskin(end_p, func():
				arena_viewport.flash_stack(target_stack)
				target_stack.buff_stoneskin_turns = 3
				_spawn_floating_text(target_stack.hex, "КАМЕННАЯ КОЖА (+5)", Color(0.85, 0.75, 0.5))
				log_combat(tr("%s покрыт каменной броней (+5 к Защите на 3 раунда)!") % tr(target_stack.data.name))
				arena_viewport.queue_redraw()
				_update_reachable_hexes()
			)
		"blind":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_blind(end_p, func():
				arena_viewport.flash_stack(target_stack)
				target_stack.debuff_blind_turns = 3
				_spawn_floating_text(target_stack.hex, "ОСЛЕПЛЕНИЕ!", Color(1.0, 0.95, 0.4))
				log_combat(tr("%s ослеплен яркой вспышкой и не может действовать!") % tr(target_stack.data.name))
				arena_viewport.queue_redraw()
				_update_reachable_hexes()
			)
			
		"inspiration":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(0.6, 1.0, 0.5))
			arena_viewport.flash_stack(target_stack)
			target_stack.debuff_blind_turns = 0
			target_stack.debuff_disease_turns = 0
			target_stack.debuff_entangle_turns = 0
			target_stack.buff_slow_turns = 0
			target_stack.buff_inspiration_turns = 3
			_spawn_floating_text(target_stack.hex, "✨ ВДОХНОВЕНИЕ!", Color(0.6, 1.0, 0.5))
			log_combat(tr("✨ С отряда %s сняты тёмные чары, боевой дух удвоен на 3 раунда!") % tr(target_stack.data.name))
		"shield_light":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(0.75, 0.9, 1.0))
			arena_viewport.flash_stack(target_stack)
			var cur_sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
			target_stack.shield_hp = 40 + cur_sp * 10
			target_stack.buff_shield_turns = 3
			_spawn_floating_text(target_stack.hex, "🛡 ЩИТ СВЕТА!", Color(0.75, 0.9, 1.0))
			log_combat(tr("🛡 %s окружен куполом света: поглощает %d ед. урона в течение 3 раундов!") % [tr(target_stack.data.name), target_stack.shield_hp])
		"retribution":
			SoundManager.play_spell_sfx(spell_id)
			var end_p = HexGrid.hex_to_pixel(target_stack.hex.x, target_stack.hex.y, HEX_SIZE, grid_origin)
			arena_viewport.spawn_holy_halo(end_p, Color(1.0, 0.65, 0.25))
			arena_viewport.flash_stack(target_stack)
			target_stack.buff_retribution_turns = 3
			_spawn_floating_text(target_stack.hex, "⚔ ВОЗМЕЗДИЕ!", Color(1.0, 0.65, 0.25))
			log_combat(tr("⚔ %s осенен печатью Возмездия: ближние атакующие получат 25%% урона ответно (3 раунда)!") % tr(target_stack.data.name))
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

## Единая точка применения боевого урона: уклонения, Щит Света,
## Возмездие, отражение Каменных Стражей и статистика боя.
func _resolve_attack_damage(attacker: BattleStack, defender: BattleStack, raw_dmg: int, is_melee: bool) -> Dictionary:
	var dmg := raw_dmg

	if is_melee:
		var dodge_ch: float = float(defender.data.get("dodge", 0.0))
		if defender.team == 0 and GameState.has_artifact_effect("mantle_wanderer"):
			dodge_ch += 0.15
		if dodge_ch > 0.0 and randf() < dodge_ch:
			dmg = maxi(1, int(dmg * 0.5))
			_spawn_floating_text(defender.hex, "💨 УКЛОНЕНИЕ!", Color(0.6, 0.9, 1.0))
			log_combat(tr("💨 %s ловко уклоняется: урон вдвое меньше!") % tr(defender.data.name))

	var res: Dictionary = defender.take_damage(dmg)
	# Искры у цели; на тяжёлом ударе поле встряхивает
	var heavy_hit := int(res["casualties"]) >= 5 or int(res["damage"]) >= 150
	arena_viewport.spawn_hit_sparks(HexGrid.hex_to_pixel(defender.hex.x, defender.hex.y, HEX_SIZE, grid_origin) + Vector2(0, -HEX_SIZE * 0.6), heavy_hit)
	if heavy_hit:
		arena_viewport.shake(7.0)

	if int(res.get("absorbed", 0)) > 0:
		_spawn_floating_text(defender.hex, tr("🛡 ЩИТ -%d") % int(res["absorbed"]), Color(0.7, 0.85, 1.0), Vector2(0, -40))

	_track_damage(attacker, defender, res)

	if is_melee and defender.buff_retribution_turns > 0 and int(res["damage"]) > 0 and attacker.is_alive():
		var ret := maxi(1, int(int(res["damage"]) * 0.25))
		var rres: Dictionary = attacker.take_damage(ret)
		_spawn_floating_text(attacker.hex, tr("⚔ ВОЗМЕЗДИЕ -%d") % int(rres["damage"]), Color(1.0, 0.6, 0.2))
		log_combat(tr("⚔ Печать Возмездия карает %s на %d урона!") % [tr(attacker.data.name), int(rres["damage"])])
		_track_damage(defender, attacker, rres)

	if is_melee and defender.is_alive() and float(defender.data.get("reflect", 0.0)) > 0.0 and int(res["damage"]) > 0:
		var refl := maxi(1, int(int(res["damage"]) * float(defender.data.get("reflect", 0.0))))
		var flres: Dictionary = attacker.take_damage(refl)
		_spawn_floating_text(defender.hex, tr("🪞 ОТРАЖЕНИЕ -%d") % int(flres["damage"]), Color(0.85, 0.85, 0.95))
		log_combat(tr("🪞 %s отражает %d урона по %s!") % [tr(defender.data.name), int(flres["damage"]), tr(attacker.data.name)])
		_track_damage(defender, attacker, flres)

	return res

func _track_damage(attacker: BattleStack, defender: BattleStack, res: Dictionary) -> void:
	if attacker.team == 0:
		battle_stats["dealt"] += int(res["damage"]) + int(res.get("absorbed", 0))
		battle_stats["enemy_losses"] += int(res["casualties"])
	else:
		battle_stats["taken"] += int(res["damage"]) + int(res.get("absorbed", 0))
		battle_stats["player_losses"] += int(res["casualties"])

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

func _battle_difficulty() -> String:
	return GameState.demo_difficulty if GameState.is_demo_battle else GameState.campaign_difficulty

## Удача — удвоенный урон: у войска героя 15%, у врага — только на «Герое» и «Легенде».
## roll подставляют тесты; по умолчанию — случайное число.
func _roll_luck(attacker: BattleStack, roll: float = -1.0) -> bool:
	var chance: float = 0.15 if attacker.team == 0 else float(GameState.get_enemy_fortune(_battle_difficulty())["luck"])
	return (randf() if roll < 0.0 else roll) < chance

## Шанс боевого духа: у войска героя 5% + 10% за уровень Лидерства (Воодушевление
## удваивает), у врага — только на «Герое» и «Легенде».
func morale_chance(stack: BattleStack) -> float:
	if stack.team == 1:
		return float(GameState.get_enemy_fortune(_battle_difficulty())["morale"])
	var chance := 0.05 + 0.10 * GameState.get_skill_level("leadership")
	if stack.buff_inspiration_turns > 0:
		chance *= 2.0 # раньше удвоение считалось уже после броска и ни на что не влияло
	return chance

## Боевой дух: после атаки отряд может сразу походить ещё раз. true — ход продлён:
## _next_turn не вызываем, врагу ход возвращает ИИ, войску героя в автобое — автобой.
func _try_morale(attacker: BattleStack, roll: float = -1.0) -> bool:
	if not attacker.is_alive() or attacker.had_morale_this_round:
		return false
	if not (_has_living_enemies() if attacker.team == 0 else _has_living_players()):
		return false
	if (randf() if roll < 0.0 else roll) >= morale_chance(attacker):
		return false
	attacker.had_morale_this_round = true
	attacker.has_acted = false
	SoundManager.play_sfx("spell_cast")
	_spawn_floating_text(attacker.hex, "🌟 БОЕВОЙ ДУХ! (+1 ХОД)", Color(1.0, 0.88, 0.2))
	log_combat(tr("🌟 [БОЕВОЙ ДУХ]: Воодушевленный отряд %s получает дополнительный ход!") % tr(attacker.data.name))
	_update_initiative_bar()
	_update_reachable_hexes()
	arena_viewport.queue_redraw()
	if attacker.team == 1:
		_handle_ai_turn()
	elif is_auto_battling:
		_execute_auto_turn_for_player()
	return true

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
			victory_desc.text = tr("🏆 Тренировочный поединок на Арене успешно завершен!\nСложность: %s\nПротивник: %s\n\nВы продемонстрировали выдающееся тактическое мастерство полководца!") % [
				tr(GameState.demo_difficulty_title), tr(GameState.demo_encounter_title)
			]
			return
		var reward_gold = pending_reward_gold
		var reward_xp = pending_reward_xp
		if GameState.pending_battle_id == "bandit_boss":
			reward_gold = 1500
			reward_xp = 1200
			GameState.has_fairy_crown = true
			if not GameState.inventory_artifacts.has("crown_fairy") and not GameState.equipped_artifacts.values().has("crown_fairy"):
				GameState.inventory_artifacts.append("crown_fairy")
			victory_desc.text = tr("Главарь разбойников повержен!\n\n★ ВЫ ВЕРНУЛИ ВЕНЕЦ КОРОЛЕВЫ ФЕЙ! ★\nПолучен легендарный артефакт: Венец Королевы Фей!\nОтнесите его в Рощу Фей на севере!\n\nНаграда:\nЗолото: +%d\nОпыт: +%d") % [reward_gold, reward_xp]
		elif GameState.pending_battle_id == "lich_boss":
			reward_gold = 2500
			reward_xp = 2200
			GameState.flags["lich_defeated"] = true
			if not GameState.inventory_artifacts.has("ring_arcana") and not GameState.equipped_artifacts.values().has("ring_arcana"):
				GameState.inventory_artifacts.append("ring_arcana")
			victory_desc.text = tr("Древний Лич сокрушен и обращен в прах!\n\n★ ПРОКЛЯТЫЕ ТОПИ ОЧИЩЕНЫ! ★\nПолучен могущественный артефакт: Перстень Архимага!\nПосетите Алтарь Друидов для завершения Главы 2!\n\nНаграда:\nЗолото: +%d\nОпыт: +%d") % [reward_gold, reward_xp]
		elif GameState.pending_battle_id == "dragon_boss":
			reward_gold = 5000
			reward_xp = 4000
			GameState.flags["dragon_defeated"] = true
			if not GameState.inventory_artifacts.has("armor_chitin") and not GameState.equipped_artifacts.values().has("armor_chitin"):
				GameState.inventory_artifacts.append("armor_chitin")
			victory_desc.text = tr("Красный Дракон повержен в легендарном поединке!\n\n★ ТРИУМФ НАД ПЛАМЕНЕМ! ★\nПолучен легендарный Панцирь Древнего Стража!\nВы покорили Пик Дракона и спасли Королевство!\n\nНаграда:\nЗолото: +%d\nОпыт: +%d") % [reward_gold, reward_xp]
		else:
			victory_desc.text = tr("Вы рассеяли вражеский отряд!\n\nПолучено награды:\nЗолото: +%d\nОпыт героя: +%d") % [reward_gold, reward_xp]
			
		# Летопись подвигов
		GameState.unlock_feat("first_blood")
		if int(battle_stats.get("player_losses", 0)) == 0:
			GameState.unlock_feat("flawless")
		match GameState.pending_battle_id:
			"bandit_boss":
				GameState.unlock_feat("boss_bandit")
			"lich_boss":
				GameState.unlock_feat("boss_lich")
			"dragon_boss":
				GameState.unlock_feat("boss_dragon")

		# Боевые артефакты за особые победы
		if GameState.pending_battle_id == "patrol_obelisk" and not GameState.has_artifact_effect("horn_of_valor") and not GameState.inventory_artifacts.has("horn_of_valor"):
			GameState.inventory_artifacts.append("horn_of_valor")
			victory_desc.text += "\n\n📯 Найден артефакт: Рог Доблести! Наденьте его в профиле героя."
		if GameState.pending_battle_id == "swamp_patrol_ruins" and not GameState.has_artifact_effect("mantle_wanderer") and not GameState.inventory_artifacts.has("mantle_wanderer"):
			GameState.inventory_artifacts.append("mantle_wanderer")
			victory_desc.text += "\n\n🧥 Найден артефакт: Плащ Странника! Наденьте его в профиле героя."

		GameState.add_gold(reward_gold)
		GameState.add_xp(reward_xp)
		
		victory_desc.text += tr("\n\n⚔ Итоги боя: раундов %d | урон %d | потери врага %d | свои потери %d") % [
			int(battle_stats.get("rounds", 0)), int(battle_stats.get("dealt", 0)),
			int(battle_stats.get("enemy_losses", 0)), int(battle_stats.get("player_losses", 0))
		]

		# Павшие в победном бою попадают в Летопись павших — их вернёт «Благодать»
		for snap in army_start_snapshot:
			var surviving := 0
			for st in all_stacks:
				if st.team == 0 and st.unit_id == str(snap["unit_id"]) and st.is_alive():
					surviving += _army_survivors(st)
			var fallen: int = maxi(0, int(snap["count"]) - surviving)
			if fallen > 0:
				GameState.add_fallen_units(str(snap["unit_id"]), fallen)

		# Save that enemy on the map is defeated
		if GameState.pending_battle_id != "":
			GameState.flags[GameState.pending_battle_id] = true
			GameState.pending_battle_id = ""
		# Сначала уцелевшие возвращаются в войско, потом сохранение — иначе на диск
		# уходит армия до боя и потери пропадают
		_sync_army_after_battle()
		GameState.save_game()
	else:
		SoundManager.play_sfx("defeat")
		victory_title.text = "ПОРАЖЕНИЕ..."
		if GameState.is_demo_battle:
			victory_desc.text = tr("Ваши воины пали на Арене!\nСложность: %s\n\nСмените тактику, подберите другой состав отрядов и попробуйте снова!") % tr(GameState.demo_difficulty_title)
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
		else:
			# Уцелевшие отступают вместе с героем — потери боя остаются (раньше армия
			# возвращалась целиком, и отступление отменяло любые потери)
			_sync_army_after_battle()
		GameState.save_game()

## Сколько воинов отряда вернётся в войско. Бой идёт с численностью, умноженной на
## сложность кампании (Новобранец ×1.35 … Легенда ×0.8), поэтому уцелевших переводим
## обратно в масштаб войска: иначе армия росла или таяла после каждого боя без потерь.
func _army_survivors(s: BattleStack) -> int:
	if not _army_counts.has(s) or s.start_count <= 0:
		return s.count
	var base: int = _army_counts[s]
	return clampi(int(round(float(base) * float(s.count) / float(s.start_count))), 1, base)

func _sync_army_after_battle() -> void:
	if GameState.is_demo_battle:
		return
	var updated_army: Array[Dictionary] = []
	for s in all_stacks:
		if s.team == 0 and s.is_alive() and s.count > 0:
			updated_army.append({"unit_id": s.unit_id, "count": _army_survivors(s)})
	if updated_army.size() > 0:
		GameState.player_army = updated_army
		GameState.state_changed.emit()

func _on_victory_continue() -> void:
	SoundManager.play_sfx("click")
	var is_demo = GameState.is_demo_battle
	var target = GameState.battle_return_scene if GameState.battle_return_scene != "" else "res://src/world/world_map.tscn"
	GameState.battle_return_scene = "" # точка возврата одноразовая (PR #2)
	if is_demo or target == "res://src/main.tscn":
		GameState.is_demo_battle = false
		var pref = SoundManager.load_music_preference()
		var theme_to_play = pref if pref != "" else "res://assets/audio/music/themes/homm2_01_sorceress_garden.ogg"
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
	log_combat(tr("%s встает в глухую оборону (+30%% к защите)!") % tr(current_actor.data.name))
	_next_turn()

func _on_wait_pressed() -> void:
	if is_ai_turn or is_animating or current_actor == null or current_actor.team != 0:
		return
	if current_actor.has_waited:
		log_combat(tr("⚠️ Отряд %s уже выжидал в этом раунде и обязан действовать!") % tr(current_actor.data.name))
		return
	SoundManager.play_sfx("click")
	current_actor.has_waited = true
	turn_queue.append(current_actor)
	current_actor = null
	log_combat("⏳ Отряд выжидает удобного момента...")
	_next_turn()

func _toggle_fast_forward() -> void:
	is_fast_forward = not is_fast_forward
	Engine.time_scale = 2.0 if is_fast_forward else 1.0
	SoundManager.play_sfx("click")
	if speed_btn:
		speed_btn.modulate = Color(0.6, 1.0, 0.6) if is_fast_forward else Color.WHITE
	log_combat(tr("⏩ Ускорение боя: %s") % ("ВКЛЮЧЕНО (x2)" if is_fast_forward else "выключено"))

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
		# Иконка с подписью (PR #3): на телефоне подсказок нет
		var cell = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(72, 72)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(sdata.icon_path):
			btn.texture_normal = load(sdata.icon_path)
		btn.tooltip_text = tr("%s (%d маны)\n%s") % [tr(sdata.name), sdata.mana_cost, tr(sdata.description)]
		btn.pressed.connect(func(): _on_spell_selected(spell_id))
		cell.add_child(btn)
		var lbl = Label.new()
		lbl.text = tr(str(sdata.name))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		lbl.custom_minimum_size = Vector2(76, 0)
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(lbl)
		container.add_child(cell)

func _on_spell_selected(spell_id: String) -> void:
	var sdata = SpellData.get_spell(spell_id)
	if GameState.current_mana < sdata.mana_cost:
		log_combat(tr("Не хватает маны на заклинание %s!") % tr(sdata.name))
		return
	if hero_cast_this_round:
		log_combat("Герой уже сотворил заклинание в этом раунде!")
		return
		
	SoundManager.play_sfx("click")
	pending_spell_id = spell_id
	spellbook_dialog.hide()
	log_combat(tr("Выберите цель для заклинания: %s (ПКМ/Esc для отмены)") % tr(sdata.name))
	arena_viewport.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				if current_actor and current_actor.team == 0 and current_actor.has_waited:
					log_combat(tr("⚠️ Отряд %s уже ждал в этом раунде и обязан действовать!") % tr(current_actor.data.name))
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
				elif retreat_confirm_dialog != null and retreat_confirm_dialog.visible:
					retreat_confirm_dialog.hide()
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
						if DisplayServer.is_touchscreen_available() and pending_attack_target != clicked_stack:
							# Первый тап: прогноз урона и подсветка, второй — удар
							pending_attack_target = clicked_stack
							_show_attack_forecast(clicked_stack)
							log_forecast(tr("⚔ %s: %d-%d урона (потери %d-%d). Тапните ещё раз для атаки!") % [
								tr(clicked_stack.data.name),
								int(hovered_forecast.get("min_dmg", 0)), int(hovered_forecast.get("max_dmg", 0)),
								int(hovered_forecast.get("min_cas", 0)), int(hovered_forecast.get("max_cas", 0))
							])
							return
						pending_attack_target = null
						_handle_player_attack(clicked_stack, event.position)
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
				pending_attack_target = null
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
				log_forecast(tr("⚡ [СЛОМАННАЯ СТРЕЛА! Дистанция %d > 5, Штраф -50%%]: Урон %d-%d (Потери: %d-%d)") % [
					dist, hovered_forecast.min_dmg, hovered_forecast.max_dmg, hovered_forecast.min_cas, hovered_forecast.max_cas
				])
			else:
				log_forecast(tr("🏹 [ПРЯМОЙ ВЫСТРЕЛ: Дистанция %d]: Урон %d-%d (Потери: %d-%d)") % [
					dist, hovered_forecast.min_dmg, hovered_forecast.max_dmg, hovered_forecast.min_cas, hovered_forecast.max_cas
				])
		elif is_shooter and is_melee_attack:
			var can_ret = (not stack.has_retaliated or stack.data.get("unlimited_retaliation", false))
			log_forecast(tr("⚔ [РУКОПАШНАЯ (СТРЕЛОК В УПОР, ШТРАФ -50%%)]: Урон %d-%d (Потери: %d-%d)%s") % [
				hovered_forecast.min_dmg, hovered_forecast.max_dmg, hovered_forecast.min_cas, hovered_forecast.max_cas,
				" [Враг ответит!]" if can_ret else " [Без ответа]"
			])
		else:
			var can_ret = (not stack.has_retaliated or stack.data.get("unlimited_retaliation", false))
			log_forecast(tr("⚔ [РУКОПАШНАЯ АТАКА]: Урон %d-%d (Потери: %d-%d)%s") % [
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
		
	var team_name = tr("Ваше войско") if stack.team == 0 else tr("Вражеский отряд")
	var max_hp = stack.data.get("max_hp", 20)
	var total_pool = (stack.count - 1) * max_hp + stack.current_hp
	
	var traits = []
	if stack.data.get("is_ranged", false):
		traits.append(tr("Стрелок (дальность 5 гексов)"))
	if stack.data.get("unlimited_retaliation", false):
		traits.append(tr("Бесконечный отпор"))
	if stack.data.get("breath_attack", false) or stack.unit_id == "red_dragon":
		traits.append(tr("Огненное дыхание (пробивает насквозь)"))
	if stack.data.get("disease", false) or stack.unit_id == "swamp_zombie":
		traits.append(tr("Трупный яд (ослабляет атаку)"))
	if stack.data.get("regeneration", 0) > 0 or stack.unit_id == "treant":
		traits.append(tr("Регенерация (+20 HP в раунд)"))
	if stack.data.get("entangle", false) or stack.unit_id == "treant":
		traits.append(tr("Оплетающие корни"))
	if float(stack.data.get("reflect", 0.0)) > 0.0:
		traits.append(tr("Отражение (%d%% ближнего урона)") % int(round(100.0 * float(stack.data.get("reflect", 0.0)))))
	if float(stack.data.get("dodge", 0.0)) > 0.0:
		traits.append(tr("Уклонение (%d%% шанс вдвое снизить ближний урон)") % int(round(100.0 * float(stack.data.get("dodge", 0.0)))))
	if stack.data.get("is_caster", false):
		traits.append(tr("Колдун (тёмное пламя по густым строям)"))
	traits.append_array(boss.trait_lines(stack.data))
	if traits.is_empty():
		traits.append(tr("Обычные боевые навыки"))
		
	var buffs = []
	if stack.buff_bless_turns > 0:
		buffs.append(tr("Благословение (%d р.)") % stack.buff_bless_turns)
	if stack.buff_haste_turns > 0:
		buffs.append(tr("Ускорение (%d р.)") % stack.buff_haste_turns)
	if stack.buff_stoneskin_turns > 0:
		buffs.append(tr("Каменная кожа (+5 защ., %d р.)") % stack.buff_stoneskin_turns)
	if stack.debuff_blind_turns > 0:
		buffs.append(tr("Ослепление (%d р.)") % stack.debuff_blind_turns)
	if stack.debuff_disease_turns > 0:
		buffs.append(tr("Болезнь (-25%% атк., %d р.)") % stack.debuff_disease_turns)
	if stack.debuff_entangle_turns > 0:
		buffs.append(tr("Опутан корнями (0 скор.)"))
	if stack.is_defending:
		buffs.append(tr("Глухая оборона (+30% защ.)"))
	if stack.aura_attack > 0:
		buffs.append(tr("Знамя вожака (+%d атк.)") % stack.aura_attack)
	var buffs_str = ", ".join(buffs) if buffs.size() > 0 else tr("Нет")
	
	unit_info_stats.text = tr("%s (%s)\nЧисленность: %d воинов\nЗдоровье верхнего воина: %d / %d HP\nВсего здоровья отряда: %d HP\n\nАтака: %d | Защита: %d\nУрон: %d-%d\nСкорость: %d | Инициатива: %d\n\nОсобенности: %s\nАктивные эффекты: %s") % [
		tr(stack.data.name), team_name, stack.count,
		stack.current_hp, max_hp, total_pool,
		int(stack.data.get("attack", 4)) + stack.aura_attack, stack.get_defense(),
		stack.data.get("min_dmg", 3), stack.data.get("max_dmg", 6),
		stack.get_speed(), stack.get_initiative(),
		", ".join(traits), buffs_str
	]
	
	unit_info_dialog.show()

## Показать прогноз урона по цели (наведение мыши или первый тап на тач).
func _show_attack_forecast(target: BattleStack) -> void:
	hovered_target = target
	var is_shooter = current_actor.data.get("is_ranged", false)
	var is_blocked = is_shooter and current_actor.is_blocked_by_enemy(all_stacks)
	var dist = HexGrid.distance(current_actor.hex, target.hex)
	var is_melee_attack = (dist == 1) or not is_shooter or is_blocked
	hovered_is_broken = is_shooter and not is_melee_attack and (dist > 5)
	hovered_forecast = current_actor.get_damage_range(target, is_melee_attack, hovered_is_broken)
	arena_viewport.queue_redraw()

func _handle_player_attack(target: BattleStack, tap_pos: Vector2 = Vector2.INF) -> void:
	var is_shooter = current_actor.data.get("is_ranged", false)
	var is_blocked = is_shooter and current_actor.is_blocked_by_enemy(all_stacks)
	var dist = HexGrid.distance(current_actor.hex, target.hex)
	var is_melee = (dist == 1) or not is_shooter or is_blocked
	if not is_melee:
		_execute_attack(current_actor, target, false)
	else:
		# Melee: move adjacent if not already adjacent
		if HexGrid.distance(current_actor.hex, target.hex) > 1:
			# Встаём с той стороны цели, куда тапнули; при равенстве — ближе к себе (PR #3)
			var best_hex := Vector2i(-99, -99)
			var best_score := 999999.0
			for r_hex in reachable_hexes:
				if HexGrid.distance(r_hex, target.hex) != 1:
					continue
				var mid: Vector2 = (HexGrid.hex_to_pixel(r_hex.x, r_hex.y, HEX_SIZE, grid_origin)
					+ HexGrid.hex_to_pixel(target.hex.x, target.hex.y, HEX_SIZE, grid_origin)) * 0.5
				var score: float = mid.distance_to(tap_pos) if tap_pos != Vector2.INF else float(HexGrid.distance(r_hex, current_actor.hex))
				if score < best_score:
					best_score = score
					best_hex = r_hex
			if best_hex != Vector2i(-99, -99):
				current_actor.hex = best_hex
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
	hero_mana_label.text = tr("Мана: %d / %d") % [GameState.current_mana, GameState.max_mana]
	hero_mana_bar.max_value = GameState.max_mana
	hero_mana_bar.value = GameState.current_mana

## Лог склеивается из нескольких строк, поэтому Label его сам не переведёт — переводим здесь.
## Уже переведённые шаблоны (tr("...") % ...) ключами не являются и проходят без изменений.
func log_combat(msg: String) -> void:
	log_history.append(tr(msg))
	while log_history.size() > 3:
		log_history.pop_front()
	_live_log_line = ""
	_refresh_log_label()

func log_forecast(msg: String) -> void:
	# Живой прогноз урона при наведении: не засоряет историю
	_live_log_line = tr(msg)
	_refresh_log_label()

func _refresh_log_label() -> void:
	var lines: Array[String] = log_history.duplicate()
	if _live_log_line != "":
		lines.append(_live_log_line)
	log_label.text = "\n".join(lines)

func _spawn_floating_text(hex: Vector2i, text: String, color: Color, custom_offset: Vector2 = Vector2.ZERO) -> void:
	var pos = HexGrid.hex_to_pixel(hex.x, hex.y, HEX_SIZE, grid_origin)
	floating_texts.append({
		"pos": pos + Vector2(0, -30) + custom_offset,
		"text": tr(text), # рисуется draw_string — сам не переводится
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
