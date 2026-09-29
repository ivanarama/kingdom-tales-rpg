class_name WorldMapScene
extends Control

const ArtifactData = preload("res://src/core/artifact_data.gd")
const UnitData = preload("res://src/core/unit_data.gd")
const SpellData = preload("res://src/core/spell_data.gd")

@onready var world_view: WorldView = $ScrollContainer/WorldView
@onready var scroll_container: ScrollContainer = $ScrollContainer

# Interactive Popups
@onready var popup_dialog: Control = $CanvasLayer/EventDialog
@onready var popup_title: Label = $CanvasLayer/EventDialog/Parchment/Margin/MainVBox/Title
@onready var popup_text: Label = $CanvasLayer/EventDialog/Parchment/Margin/MainVBox/Scroll/ScrollMargin/Text
@onready var popup_btn1: Button = $CanvasLayer/EventDialog/Parchment/Margin/MainVBox/BtnVBox/Btn1
@onready var popup_btn2: Button = $CanvasLayer/EventDialog/Parchment/Margin/MainVBox/BtnVBox/Btn2
@onready var popup_close: Button = $CanvasLayer/EventDialog/Parchment/CloseBtn

# Split Dialog
@onready var split_dialog: Control = $CanvasLayer/SplitStackDialog
@onready var split_title: Label = $CanvasLayer/SplitStackDialog/Parchment/Title
@onready var split_info: Label = $CanvasLayer/SplitStackDialog/Parchment/StackInfoLabel
@onready var split_slider: HSlider = $CanvasLayer/SplitStackDialog/Parchment/SplitSlider
@onready var split_value_lbl: Label = $CanvasLayer/SplitStackDialog/Parchment/SplitValueLabel
@onready var split_confirm_btn: Button = $CanvasLayer/SplitStackDialog/Parchment/HBox/ConfirmSplitBtn
@onready var split_cancel_btn: Button = $CanvasLayer/SplitStackDialog/Parchment/HBox/CancelSplitBtn

var current_split_slot: int = -1

# HUD
@onready var name_label: Label = $CanvasLayer/TopHUD/NameLabel
@onready var gold_label: Label = $CanvasLayer/TopHUD/GoldLabel
@onready var mana_label: Label = $CanvasLayer/TopHUD/ManaLabel
@onready var day_label: Label = $CanvasLayer/TopHUD/DayLabel
@onready var mp_label: Label = $CanvasLayer/TopHUD/MoveLabel
@onready var mp_bar: ProgressBar = $CanvasLayer/TopHUD/MoveBar
@onready var army_container: VBoxContainer = $CanvasLayer/LeftArmyPanel/Parchment/ArmyVBox
@onready var army_title: Label = $CanvasLayer/LeftArmyPanel/Parchment/Title
var selected_army_slot: int = -1
var _army_panel_sig: String = ""
var _minimap_redraw_accum: float = 0.0
var chronicle_dialog: Control

# Quest HUD
@onready var quest_label: Label = $CanvasLayer/QuestHUD/QuestLabel

# Campaign Victory Dialog
@onready var victory_dialog: Control = $CanvasLayer/VictoryDialog
@onready var victory_title: Label = $CanvasLayer/VictoryDialog/Parchment/Title
@onready var victory_text: Label = $CanvasLayer/VictoryDialog/Parchment/Text
@onready var victory_continue_btn: Button = $CanvasLayer/VictoryDialog/Parchment/HBox/ContinueBtn
@onready var victory_menu_btn: Button = $CanvasLayer/VictoryDialog/Parchment/HBox/MenuBtn

# Hero Profile Dialog
@onready var hero_dialog: Control = $CanvasLayer/HeroProfileDialog
@onready var hero_close_btn: Button = $CanvasLayer/HeroProfileDialog/Parchment/CloseBtn
@onready var hero_name_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/HeroHeaderHBox/HeaderTextVBox/HeroName
@onready var hero_level_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/HeroHeaderHBox/HeaderTextVBox/LevelLabel
@onready var hero_xp_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/HeroHeaderHBox/HeaderTextVBox/XPLabel
@onready var hero_xp_bar: ProgressBar = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/HeroHeaderHBox/HeaderTextVBox/XPBar
@onready var hero_att_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/AttackLabel
@onready var hero_def_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/DefenseLabel
@onready var hero_sp_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/SpellpowerLabel
@onready var hero_kn_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/KnowledgeLabel
@onready var hero_set_bonus_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/SetBonusLabel
@onready var hero_relics_lbl: Label = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/LeftCol/RelicsScroll/RelicsLabel
@onready var mannequin_box: Control = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/MidCol/MannequinBox
@onready var backpack_vbox: VBoxContainer = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/MidCol/BackpackScroll/BackpackVBox
@onready var hero_skills_vbox: VBoxContainer = $CanvasLayer/HeroProfileDialog/Parchment/ContentHBox/RightCol/SkillsScroll/SkillsVBox

# Level Up Dialog
@onready var level_dialog: Control = $CanvasLayer/LevelUpDialog
@onready var level_sub_lbl: Label = $CanvasLayer/LevelUpDialog/Parchment/Subtitle
@onready var level_stat_lbl: Label = $CanvasLayer/LevelUpDialog/Parchment/StatGainLabel
@onready var level_skill_btn1: Button = $CanvasLayer/LevelUpDialog/Parchment/VBox/SkillBtn1
@onready var level_skill_btn2: Button = $CanvasLayer/LevelUpDialog/Parchment/VBox/SkillBtn2

# Confirm End Day Dialog
@onready var confirm_end_day_dialog: Control = $CanvasLayer/ConfirmEndDayDialog
@onready var confirm_end_day_prompt: Label = $CanvasLayer/ConfirmEndDayDialog/Parchment/Margin/VBox/Prompt
@onready var confirm_end_day_confirm_btn: Button = $CanvasLayer/ConfirmEndDayDialog/Parchment/Margin/VBox/HBox/ConfirmBtn
@onready var confirm_end_day_cancel_btn: Button = $CanvasLayer/ConfirmEndDayDialog/Parchment/Margin/VBox/HBox/CancelBtn

var minimap_container: Control
var minimap_canvas: Control
var pause_dialog: Control
var cancel_movement: bool = false
var movement_start_time: int = 0
var planned_path: Array[Vector2i] = []
var planned_destination: Vector2i = Vector2i(-1, -1)

func _clear_planned_route() -> void:
	planned_path.clear()
	planned_destination = Vector2i(-1, -1)
	if world_view:
		world_view.clear_planned_route()

func cancel_hero_movement() -> void:
	cancel_movement = true
	_clear_planned_route()

func _ready() -> void:
	# Подборка главы: её тема чередуется с темами музыкальной шкатулки
	match GameState.current_chapter:
		2:
			SoundManager.play_playlist("map_2")
		3:
			SoundManager.play_playlist("map_3")
		_:
			SoundManager.play_playlist("map_1")

	_update_hud()
	_update_quest_hud()
	_setup_minimap_and_menu()
	GameState.state_changed.connect(_update_hud)
	GameState.state_changed.connect(_update_quest_hud)
	
	world_view.cell_clicked.connect(_on_cell_clicked)
	world_view.cancel_movement_requested.connect(cancel_hero_movement)
	$CanvasLayer/TopHUD/EndDayBtn.pressed.connect(_on_end_day_pressed)
	$CanvasLayer/SpellbookBtn.pressed.connect(func(): 
		SoundManager.play_sfx("page_turn")
		_open_spellbook()
	)
	var sb_close = $CanvasLayer/SpellbookDialog/Parchment.get_node_or_null("CloseBtn")
	if sb_close:
		sb_close.pressed.connect(func(): $CanvasLayer/SpellbookDialog.hide())
	var scry_btn = $CanvasLayer/SpellbookDialog.get_node_or_null("Parchment/Margin/MainVBox/Scroll/ContentVBox/AdvCardsHBox/ScryCard/CardVBox/ScryBtn")
	if scry_btn:
		scry_btn.pressed.connect(_cast_scrying)
	var rest_btn = $CanvasLayer/SpellbookDialog.get_node_or_null("Parchment/Margin/MainVBox/Scroll/ContentVBox/AdvCardsHBox/RestCard/CardVBox/RestBtn")
	if rest_btn:
		rest_btn.pressed.connect(_cast_restoration)
	popup_close.pressed.connect(func(): popup_dialog.hide())
	if army_title:
		army_title.mouse_filter = Control.MOUSE_FILTER_STOP
		army_title.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if selected_army_slot != -1:
					selected_army_slot = -1
					SoundManager.play_sfx("click")
					_update_hud()
		)
	
	# Split Dialog Connections
	split_slider.value_changed.connect(_on_split_slider_changed)
	split_cancel_btn.pressed.connect(func(): split_dialog.hide())
	split_confirm_btn.pressed.connect(_on_confirm_split)
	
	# Campaign Victory Dialog Connections
	victory_continue_btn.pressed.connect(_on_victory_continue_pressed)
	victory_menu_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		if GameState.current_chapter == 1 and GameState.quest_completed:
			GameState.start_chapter(2)
		elif GameState.current_chapter == 2 and GameState.quest_completed:
			GameState.start_chapter(3)
		else:
			GameState.save_game()
		get_tree().change_scene_to_file("res://src/main.tscn")
	)

	# Hero Profile Connections
	$CanvasLayer/TopHUD/Portrait.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_hero_profile()
	)
	hero_close_btn.pressed.connect(func(): hero_dialog.hide())

	# Level Up System Connection
	GameState.level_up_pending.connect(func(_info): _process_next_level_up())
	if GameState.pending_level_ups.size() > 0:
		_process_next_level_up()

	# Confirm End Day Dialog Connections
	if confirm_end_day_confirm_btn:
		confirm_end_day_confirm_btn.pressed.connect(func():
			confirm_end_day_dialog.hide()
			_execute_end_day()
		)
	if confirm_end_day_cancel_btn:
		confirm_end_day_cancel_btn.pressed.connect(func():
			SoundManager.play_sfx("click")
			confirm_end_day_dialog.hide()
		)

	# Ensure any defeated encounters or opened chests are purged from world_view.objects
	if world_view and world_view.objects:
		for c in world_view.objects.keys().duplicate():
			var oid = world_view.objects[c].get("id", "")
			if oid != "" and GameState.flags.get(oid, false):
				var otype = world_view.objects[c].get("type", "")
				if otype in ["encounter", "bandit_boss", "lich_boss", "dragon_boss", "chest"]:
					world_view.objects.erase(c)
		world_view.queue_redraw()
	
	# Восстановить бродячего торговца из сохранения
	if GameState.merchant_cell.x >= 0:
		world_view.objects[GameState.merchant_cell] = {"type": "merchant", "name": "Бродячий торговец", "id": "wandering_merchant"}
		if GameState.merchant_offers.is_empty():
			GameState.spawn_merchant_offers()

	# Initial camera centering on hero
	await get_tree().process_frame
	_center_camera_on_hero()

	# Check if returning from defeating bosses
	if GameState.has_fairy_crown and not GameState.quest_completed and not GameState.flags.get("crown_recovered_notified", false):
		GameState.flags["crown_recovered_notified"] = true
		world_view._reveal_fog(Vector2i(27, 4), 5)
		world_view.queue_redraw()
		_show_crown_recovered_popup()
	elif GameState.flags.get("bandit_boss", false) and not GameState.quest_completed and not GameState.flags.get("all_enemies_notified", false):
		GameState.flags["all_enemies_notified"] = true
		world_view._reveal_fog(Vector2i(27, 4), 5)
		world_view.queue_redraw()
		_show_crown_recovered_popup()
	elif GameState.flags.get("lich_defeated", false) and not GameState.quest_completed and not GameState.flags.get("lich_defeated_notified", false):
		GameState.flags["lich_defeated_notified"] = true
		world_view._reveal_fog(Vector2i(27, 4), 6)
		world_view.queue_redraw()
		_show_lich_defeated_popup()
	elif GameState.flags.get("dragon_defeated", false) and not GameState.quest_completed and not GameState.flags.get("dragon_defeated_notified", false):
		GameState.flags["dragon_defeated_notified"] = true
		world_view._reveal_fog(Vector2i(27, 4), 6)
		world_view.queue_redraw()
		_show_dragon_defeated_popup()
	elif not GameState.flags.get(tr("chapter_intro_seen_%d") % GameState.current_chapter, false):
		GameState.flags[tr("chapter_intro_seen_%d") % GameState.current_chapter] = true
		_show_chapter_intro()
	elif world_view and world_view.objects.has(world_view.hero_cell):
		var hero_obj = world_view.objects[world_view.hero_cell]
		if hero_obj.get("type", "") == "chest":
			var hero_guard = _find_guard_for_cell(world_view.hero_cell)
			if hero_guard.is_empty() and not GameState.flags.get(hero_obj.get("id", ""), false):
				_trigger_object(hero_obj)
	elif world_view:
		# Сундук, чья охрана только что пала, открываем и с соседней клетки
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cc: Vector2i = world_view.hero_cell + n
			if world_view.objects.has(cc) and world_view.objects[cc].get("type", "") == "chest":
				var cg: Dictionary = _find_guard_for_cell(cc)
				var cid: String = world_view.objects[cc].get("id", "")
				if cg.is_empty() and not GameState.flags.get(cid, false):
					_trigger_object(world_view.objects[cc])
					break


func _center_camera_on_hero() -> void:
	var target_pos = world_view.hero_pixel_pos
	var view_size = scroll_container.size
	scroll_container.scroll_horizontal = int(max(0, target_pos.x - view_size.x / 2.0))
	scroll_container.scroll_vertical = int(max(0, target_pos.y - view_size.y / 2.0))

var map_zoom: float = 1.0

func _set_map_zoom(new_zoom: float) -> void:
	map_zoom = clampf(new_zoom, 0.75, 1.35)
	if is_instance_valid(world_view):
		world_view.scale = Vector2(map_zoom, map_zoom)
		world_view.custom_minimum_size = Vector2(
			world_view.MAP_COLS * world_view.TILE_SIZE * map_zoom,
			world_view.MAP_ROWS * world_view.TILE_SIZE * map_zoom
		)
		world_view.queue_redraw()
	_center_camera_on_hero()

func _unhandled_input(event: InputEvent) -> void:
	if world_view.is_moving:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			cancel_hero_movement()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if planned_path.size() > 0 and not world_view.is_moving:
				_clear_planned_route()
				SoundManager.play_sfx("click")
				return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_map_zoom(map_zoom + 0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_map_zoom(map_zoom - 0.08)

	if event is InputEventKey and event.pressed and not event.echo:
		if confirm_end_day_dialog and confirm_end_day_dialog.visible:
			match event.keycode:
				KEY_ESCAPE:
					SoundManager.play_sfx("click")
					confirm_end_day_dialog.hide()
					get_viewport().set_input_as_handled()
					return
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
					confirm_end_day_dialog.hide()
					_execute_end_day()
					get_viewport().set_input_as_handled()
					return
				_:
					return

		match event.keycode:
			KEY_E:
				if not _is_any_modal_open():
					_on_end_day_pressed()
			KEY_H, KEY_C:
				if not _is_any_modal_open():
					_toggle_hero_profile()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				if not _is_any_modal_open():
					_set_map_zoom(map_zoom + 0.1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				if not _is_any_modal_open():
					_set_map_zoom(map_zoom - 0.1)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if not _is_any_modal_open():
					if planned_path.size() > 0 and not world_view.is_moving:
						var p = planned_path.duplicate()
						_clear_planned_route()
						if GameState.move_points > 0:
							_move_hero_along_path(p)
						else:
							SoundManager.play_sfx("click")
					elif world_view.objects.has(world_view.hero_cell):
						_trigger_object(world_view.objects[world_view.hero_cell])
			KEY_S:
				SoundManager.play_sfx("page_turn")
				if $CanvasLayer/SpellbookDialog.visible:
					$CanvasLayer/SpellbookDialog.hide()
				else:
					_open_spellbook()
			KEY_ESCAPE:
				if planned_path.size() > 0 and not world_view.is_moving:
					_clear_planned_route()
				elif level_dialog.visible:
					pass # Must pick a skill
				elif hero_dialog.visible:
					hero_dialog.hide()
				elif victory_dialog.visible:
					victory_dialog.hide()
				elif popup_dialog.visible:
					popup_dialog.hide()
				elif split_dialog.visible:
					split_dialog.hide()
				elif $CanvasLayer/SpellbookDialog.visible:
					$CanvasLayer/SpellbookDialog.hide()
				elif pause_dialog != null and pause_dialog.visible:
					pause_dialog.hide()
				else:
					_toggle_pause_menu()

func _on_cell_clicked(target_cell: Vector2i) -> void:
	# Block clicks while any modal popup is open
	if popup_dialog.visible or (split_dialog != null and split_dialog.visible) or $CanvasLayer/SpellbookDialog.visible or (victory_dialog != null and victory_dialog.visible) or hero_dialog.visible or level_dialog.visible or (pause_dialog != null and pause_dialog.visible) or (confirm_end_day_dialog != null and confirm_end_day_dialog.visible):
		return
		
	if world_view.is_moving:
		cancel_hero_movement()
		return
	if not world_view.is_passable(target_cell):
		return
		
	# Clicking on hero's current cell
	if target_cell == world_view.hero_cell:
		if world_view.objects.has(target_cell):
			_clear_planned_route()
			_trigger_object(world_view.objects[target_cell])
			return
		elif planned_path.size() > 0:
			var p = planned_path.duplicate()
			_clear_planned_route()
			if GameState.move_points > 0:
				_move_hero_along_path(p)
			else:
				SoundManager.play_sfx("click")
			return
		return

	# Direct interaction when clicking on an adjacent chest
	if world_view.objects.has(target_cell) and world_view.objects[target_cell].get("type", "") == "chest":
		var is_adjacent = absi(target_cell.x - world_view.hero_cell.x) <= 1 and absi(target_cell.y - world_view.hero_cell.y) <= 1
		if is_adjacent:
			_clear_planned_route()
			var has_pf = GameState.has_skill("pathfinding") if GameState.has_method("has_skill") else false
			var step_cost = WorldNavigator.move_step_cost(target_cell, world_view.road_cells, has_pf)
			if GameState.move_points >= step_cost and world_view.is_passable(target_cell):
				GameState.move_points -= step_cost
				world_view.hero_cell = target_cell
				world_view.hero_pixel_pos = world_view.cell_to_pixel(target_cell)
				world_view._reveal_fog(target_cell, 5)
				GameState.hero_cell = target_cell
				GameState.revealed_cells = world_view.revealed_cells
				_update_hud()
			_trigger_object(world_view.objects[target_cell])
			return
		
	# CLICK 2 (Confirm & Move): If clicked on the already planned destination (or target is end of planned route)
	if target_cell == planned_destination or (planned_path.size() > 0 and target_cell == planned_path[-1]):
		var p = planned_path.duplicate()
		_clear_planned_route()
		if GameState.move_points <= 0:
			SoundManager.play_sfx("click")
			return
		_move_hero_along_path(p)
		return
		
	# CLICK 1 (Plot Route): Target is a new destination
	var bounds = Rect2i(0, 0, world_view.MAP_COLS, world_view.MAP_ROWS)
	var has_pf = GameState.has_skill("pathfinding") if GameState.has_method("has_skill") else false
	var path = WorldNavigator.find_path(world_view.hero_cell, target_cell, world_view.get_path_obstacles(target_cell), bounds, world_view.road_cells, has_pf)
	if path.is_empty():
		SoundManager.play_sfx("click")
		_clear_planned_route()
		return
		
	# Route planned and locked! Wait for second click (or Space) to move
	SoundManager.play_sfx("click")
	planned_destination = target_cell
	planned_path = path
	world_view.set_planned_route(path, target_cell)

func _move_hero_along_path(path: Array[Vector2i]) -> void:
	world_view.is_moving = true
	cancel_movement = false
	movement_start_time = Time.get_ticks_msec()
	world_view.movement_start_time = movement_start_time
	_clear_planned_route()
	world_view.preview_path.clear()
	
	for next_cell in path:
		if cancel_movement:
			cancel_movement = false
			break
			
		# Патруль, босс или запертые врата: в клетку не входим, взаимодействуем с соседней (PR #2)
		if world_view.objects.has(next_cell) and WorldView.is_blocking_object(world_view.objects[next_cell]):
			world_view.is_moving = false
			cancel_movement = false
			world_view.queue_redraw()
			_trigger_object(world_view.objects[next_cell])
			return
		var has_pf = GameState.has_skill("pathfinding") if GameState.has_method("has_skill") else false
		var step_cost = WorldNavigator.move_step_cost(next_cell, world_view.road_cells, has_pf)
		if GameState.move_points < step_cost:
			_show_no_mp_hint()
			break
			
		# Determine direction
		var dir = next_cell - world_view.hero_cell
		world_view.move_dir = dir
		world_view.facing_dir = dir
		if dir.x > 0:
			world_view.facing_right = true
		elif dir.x < 0:
			world_view.facing_right = false
			
		# Gallop step
		SoundManager.play_sfx("horse_gallop")
		GameState.move_points -= step_cost
		_update_hud()
		
		# Smooth interpolation over 0.22s
		var start_p = world_view.hero_pixel_pos
		var end_p = world_view.cell_to_pixel(next_cell)
		var elapsed = 0.0
		var dur = 0.22
		
		while elapsed < dur:
			elapsed += get_process_delta_time()
			var t = clampf(elapsed / dur, 0.0, 1.0)
			world_view.hero_pixel_pos = start_p.lerp(end_p, t)
			world_view.queue_redraw()
			_center_camera_on_hero()
			await get_tree().process_frame
			
		world_view.hero_cell = next_cell
		world_view.hero_pixel_pos = end_p
		world_view._reveal_fog(next_cell, 5)
		world_view.queue_redraw()
		
		# Persist position and fog in GameState
		GameState.hero_cell = next_cell
		GameState.revealed_cells = world_view.revealed_cells
		
		# Check object arrival
		if world_view.objects.has(next_cell):
			var obj = world_view.objects[next_cell]
			world_view.is_moving = false
			cancel_movement = false
			_trigger_object(obj)
			return
			
		if cancel_movement:
			cancel_movement = false
			break
			
	world_view.is_moving = false
	cancel_movement = false
	world_view.queue_redraw()

func _get_object_cell(obj: Dictionary) -> Vector2i:
	if obj.has("cell") and obj["cell"] is Vector2i:
		return obj["cell"]
	var obj_id = obj.get("id", "")
	for c in world_view.objects.keys():
		if world_view.objects[c] == obj:
			return c
		if obj_id != "" and world_view.objects[c].get("id", "") == obj_id:
			return c
	return world_view.hero_cell

func _find_guard_for_cell(cell: Vector2i) -> Dictionary:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var check_cell = cell + Vector2i(dx, dy)
			if world_view.objects.has(check_cell):
				var obj = world_view.objects[check_cell]
				var otype = obj.get("type", "")
				var oid = obj.get("id", "")
				if otype in ["encounter", "bandit_boss", "lich_boss", "dragon_boss"]:
					if not GameState.flags.get(oid, false):
						return obj
	return {}

func _trigger_guarded_chest(guard: Dictionary, chest: Dictionary) -> void:
	SoundManager.play_sfx("sword_hit")
	var guard_name = tr(guard.get("name", "Вражеский отряд"))
	var guard_id = guard.get("id", "")
	popup_title.text = "⚔ ОХРАНА СОКРОВИЩ!"
	popup_text.text = tr("Этот сундук охраняет %s!\n\nВраги замечают ваше приближение, обнажают оружие и нападают на вас!\nСначала одолейте охрану, чтобы забрать сокровища!") % guard_name
	
	popup_btn1.text = "⚔ В БОЙ С ОХРАНОЙ!"
	popup_btn1.pressed.connect(func():
		SoundManager.play_sfx("sword_hit")
		_start_battle(guard_id)
	)
	
	popup_btn2.visible = true
	popup_btn2.text = "⚡ Быстрый бой"
	popup_btn2.pressed.connect(func():
		_execute_quick_combat(guard_id, func():
			if not chest.is_empty():
				_trigger_object(chest)
		)
	)
	_show_popup_dialog()

## Запуск тактического боя: точка возврата всегда — карта кампании (PR #2).
func _start_battle(battle_id: String) -> void:
	GameState.pending_battle_id = battle_id
	GameState.battle_return_scene = "res://src/world/world_map.tscn"
	get_tree().change_scene_to_file("res://src/battle/battle_arena.tscn")

func _trigger_object(obj: Dictionary) -> void:
	SoundManager.play_sfx("page_turn")
	popup_btn1.visible = true
	popup_btn2.visible = false
	
	_reset_popup_buttons()

	var obj_type = obj.get("type", "")
	var obj_id = obj.get("id", "")
	
	match obj_type:
		"merchant":
			if GameState.merchant_offers.is_empty():
				popup_title.text = tr("Бродячий торговец")
				popup_text.text = tr("«Товары на сегодня распроданы, добрый рыцарь! Загляните на следующей неделе!»")
				popup_btn1.text = tr("До встречи")
				for conn in popup_btn1.pressed.get_connections():
					popup_btn1.pressed.disconnect(conn.callable)
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
				popup_btn2.visible = false
				_show_popup_dialog()
				return
			popup_title.text = tr("🧳 Бродячий торговец")
			var desc_lines: Array[String] = []
			for i in range(GameState.merchant_offers.size()):
				var offer: Dictionary = GameState.merchant_offers[i]
				if offer["kind"] == "artifact":
					var mart: Dictionary = ArtifactData.get_artifact(str(offer["id"]))
					desc_lines.append(tr("%d) %s — артефакт (%d зол.)") % [i + 1, tr(str(mart.get("name", ""))), int(offer["price"])])
				else:
					var munit: Dictionary = UnitData.get_unit(str(offer["id"]))
					desc_lines.append(tr("%d) Отряд «%s» ×%d — (%d зол.)") % [i + 1, tr(str(munit.get("name", ""))), int(offer["count"]), int(offer["price"])])
			popup_text.text = tr("«Торг здесь прост, сэр рыцарь: цены честные, товары редкие!»\n\n") + "\n".join(desc_lines)
			var buy_btns := [popup_btn1, popup_btn2]
			for bi in range(2):
				var btn: Button = buy_btns[bi]
				for conn in btn.pressed.get_connections():
					btn.pressed.disconnect(conn.callable)
				if bi < GameState.merchant_offers.size():
					var offer_idx: int = bi
					var m_offer: Dictionary = GameState.merchant_offers[bi]
					var label: String = ""
					if m_offer["kind"] == "artifact":
						label = tr("Купить: %s (%d зол.)") % [tr(str(ArtifactData.get_artifact(str(m_offer["id"])).get("name", ""))), int(m_offer["price"])]
					else:
						label = tr("Купить: %s ×%d (%d зол.)") % [tr(str(UnitData.get_unit(str(m_offer["id"])).get("name", ""))), int(m_offer["count"]), int(m_offer["price"])]
					btn.text = label
					btn.visible = true
					btn.pressed.connect(func():
						if m_offer["kind"] != "artifact" and not GameState.can_add_units(str(m_offer["id"])):
							_show_army_full_popup()
							return
						if GameState.buy_merchant_offer(offer_idx):
							SoundManager.play_sfx("coin")
							_update_hud()
						popup_dialog.hide()
					)
				else:
					btn.visible = false
			_show_popup_dialog()

		"signpost":
			popup_title.text = "Путевой Камень"
			popup_text.text = "На замшелом камне высечены древние указатели:\n\n← На юг: Хижина Старого Лесника\n↑ На север: Водяная Мельница и Святилище Маны\n→ На восток: Железные Врата и Долина Разбойников\n\n[Подсказка: Пробел — исследовать место под конем, E — следующий день]"
			popup_btn1.text = "В путь!"
			popup_btn1.pressed.connect(func(): popup_dialog.hide())

		"mill":
			popup_title.text = "Старая Водяная Мельница"
			if GameState.flags.get(obj_id, false):
				popup_text.text = "Колесо мерно вращается в потоке воды. Мельник уже одарил ваше войско на этой неделе."
				popup_btn1.text = "Продолжить путь"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			else:
				popup_text.text = "«Приветствую, благородный рыцарь! Мельница работает в поте лица, примите 500 золотых монет на содержание гарнизона!»"
				popup_btn1.text = "Принять 500 золота"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("coin")
					GameState.add_gold(500)
					GameState.flags[obj_id] = true
					popup_dialog.hide()
				)
				
		"chest":
			if obj_id != "" and GameState.flags.get(obj_id, false):
				world_view.remove_object_by_id(obj_id)
				var c_cell = _get_object_cell(obj)
				world_view.remove_object_at(c_cell)
				popup_dialog.hide()
				return
				
			var chest_cell = _get_object_cell(obj)
			var guard = _find_guard_for_cell(chest_cell)
			if not guard.is_empty():
				_trigger_guarded_chest(guard, obj)
				return
			popup_title.text = "Сундук с Сокровищами"
			popup_text.text = "Среди трав вы нашли дубовый сундук, набитый золотом и самоцветами!\n\nЧто вы решите сделать?"
			popup_btn1.text = "Забрать 1000 золота в казну"
			popup_btn2.visible = true
			popup_btn2.text = "Раздать крестьянам (+600 опыта)"
			popup_btn1.pressed.connect(func():
				SoundManager.play_sfx("coin")
				GameState.add_gold(1000)
				GameState.flags[obj_id] = true
				world_view.remove_object_by_id(obj_id)
				world_view.remove_object_at(chest_cell)
				world_view.queue_redraw()
				_update_hud()
				GameState.save_game()
				popup_dialog.hide()
			)
			popup_btn2.pressed.connect(func():
				SoundManager.play_sfx("victory")
				GameState.add_xp(600)
				GameState.flags[obj_id] = true
				world_view.remove_object_by_id(obj_id)
				world_view.remove_object_at(chest_cell)
				world_view.queue_redraw()
				_update_hud()
				GameState.save_game()
				popup_dialog.hide()
			)
				
		"fountain":
			popup_title.text = "Святилище Маны"
			popup_text.text = "Волшебный фонтан освещает поляну мягким лазурным сиянием.\n\nГерой восполняет всю ману и ощущает прилив колдовских сил (+1 к Силе Магии)!"
			popup_btn1.text = "Испить из источника"
			popup_btn1.pressed.connect(func():
				SoundManager.play_sfx("spell_cast")
				if int(GameState.flags.get("mana_fountain_day", 0)) != GameState.day:
					GameState.restore_mana()
					GameState.flags["mana_fountain_day"] = GameState.day
				if not GameState.flags.get(obj_id, false):
					GameState.spellpower += 1
					GameState.flags[obj_id] = true
				popup_dialog.hide()
			)
			
		"fairy_dwelling", "druid_camp", "griffin_roost":
			_open_dwelling_popup(obj_id)

		"event":
			_open_map_event(obj_id)

		"forester":
			popup_title.text = "Хижина Старого Лесника"
			if GameState.quest_completed:
				popup_text.text = "«Слава сэру Аларику! Лес снова полон света и птичьего пения. Вы избавили нас от напасти!»"
				popup_btn1.text = "Поклониться"
				for conn in popup_btn1.pressed.get_connections():
					popup_btn1.pressed.disconnect(conn.callable)
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
				var avail_fx: int = GameState.dwelling_stock.get("forester_fox", 0)
				var fx_cost := 45
				if avail_fx > 0:
					popup_text.text += "\n\n" + tr("«Лесные духи-лисы желают путешествовать с вами: %d шт. (по %d золота). Казна: %d.»") % [avail_fx, fx_cost, GameState.gold]
					popup_btn2.visible = true
					popup_btn2.text = tr("Нанять лис-оборотней (%d за %d зол.)") % [avail_fx, avail_fx * fx_cost]
					for conn in popup_btn2.pressed.get_connections():
						popup_btn2.pressed.disconnect(conn.callable)
					popup_btn2.pressed.connect(func():
						if not GameState.can_add_units("fox_shifter"):
							_show_army_full_popup()
							return
						if GameState.spend_gold(avail_fx * fx_cost):
							SoundManager.play_sfx("coin")
							GameState.dwelling_stock["forester_fox"] -= avail_fx
							GameState.add_units_to_army("fox_shifter", avail_fx)
							popup_dialog.hide()
					)
				else:
					popup_btn2.visible = false
			elif GameState.quest_forester_started:
				popup_text.text = "«Врата открыты, паладин! Спешите на восток — разбейте атамана в его логове и верните Венец Королеве Фей!»"
				popup_btn1.text = "Я выполню долг!"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			else:
				popup_title.text = "Квест: Похищенный Венец"
				popup_text.text = "Старый лесничий взволнован:\n\n«Беда, сэр Аларик! Шайка разбойников из ущелья похитила древний Венец Королевы Фей! Без него гибнет вся магия нашего леса. Бандиты заперли ущелье Железными Вратами.\n\nВот кованый Ключ от Врат! Прогоните атамана и отнесите Венец в Рощу Фей на севере долины!»"
				popup_btn1.text = "Принять ключ и отправиться в поход"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("victory")
					GameState.has_gate_key = true
					GameState.quest_forester_started = true
					popup_dialog.hide()
				)

		"gate":
			popup_title.text = "Железные Врата Ущелья"
			if GameState.flags.get("iron_gate_opened", false):
				popup_text.text = "Кованые врата распахнуты настежь. Дорога через горный перевал свободна!"
				popup_btn1.text = "Продолжить путь"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			elif GameState.has_gate_key:
				popup_text.text = "Вы вставляете ключ Лесника в замковую скважину. Раздается гулкий щелчок — массивные железные створки со скрипом распахиваются!\n\nПроход в Долину Разбойников открыт!"
				popup_btn1.text = "Пройти через врата"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("sword_hit")
					GameState.flags["iron_gate_opened"] = true
					popup_dialog.hide()
				)
			else:
				popup_text.text = "Массивные Железные Врата наглухо заперты стальным засовом. Из-за скал доносится вой лютых волков.\n\nВам нужен Ключ от Врат! (Посетите Хижину Лесника на юге)."
				popup_btn1.text = "Отступить назад"
				popup_btn1.pressed.connect(func():
					world_view.hero_cell = Vector2i(13, 11)
					world_view.hero_pixel_pos = world_view.cell_to_pixel(Vector2i(13, 11))
					world_view.queue_redraw()
					GameState.hero_cell = Vector2i(13, 11)
					popup_dialog.hide()
				)

		"encounter":
			if GameState.flags.get(obj_id, false):
				world_view.remove_object_by_id(obj_id)
				popup_dialog.hide()
				return
			var en_name = tr(obj.get("name", "Вражеский отряд"))
			popup_title.text = en_name
			popup_text.text = _get_encounter_desc(obj_id, en_name)
			popup_btn1.text = "⚔ В БОЙ! (Тактическая арена)"
			popup_btn1.pressed.connect(func():
				SoundManager.play_sfx("sword_hit")
				_start_battle(obj_id)
			)
			popup_btn2.visible = true
			popup_btn2.text = "⚡ Быстрый бой (Авторасчет)"
			popup_btn2.pressed.connect(func(): _execute_quick_combat(obj_id))

		"bandit_boss":
			if GameState.flags.get(obj_id, false) or GameState.has_fairy_crown:
				world_view.remove_object_by_id(obj_id)
				popup_dialog.hide()
				return
			popup_title.text = "Логово Атамана Разбойников"
			popup_text.text = "Перед вами главная цитадель разбойников!\nЗдесь засел свирепый Атаман со сворой волков и оскверненным древнем [Тьма (50+ врагов)]!\n\nОни охраняют похищенный Венец Королевы Фей!"
			popup_btn1.text = "⚔ СОКРУШИТЬ АТАМАНА!"
			popup_btn1.pressed.connect(func():
				SoundManager.play_sfx("sword_hit")
				_start_battle("bandit_boss")
			)
			popup_btn2.visible = true
			popup_btn2.text = "⚡ Быстрый бой"
			popup_btn2.pressed.connect(func(): _execute_quick_combat("bandit_boss"))

		"obelisk":
			popup_title.text = "Древний Обелиск Силы"
			if GameState.flags.get(obj_id, false):
				popup_text.text = "Древние письмена потускнели. Обелиск уже даровал вам свою благодать."
				popup_btn1.text = "Отойти"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			elif GameState.flags.get("patrol_obelisk", false):
				var avail_sg: int = GameState.dwelling_stock.get("obelisk_guard", 0)
				var sg_cost := 200
				popup_text.text = "Руны гаснут: стражи Обелиска пали в бою, и древние изваяния признали вашу доблесть. Один из Каменных Стражей готов следовать за вами!"
				if avail_sg > 0:
					popup_text.text += "\n\n" + tr("В наличии: %d страж(а) (по %d золота). Казна: %d.") % [avail_sg, sg_cost, GameState.gold]
					popup_btn1.text = tr("Нанять Каменного Стража (%d зол.)") % sg_cost
					popup_btn1.pressed.connect(func():
						if not GameState.can_add_units("stone_guardian"):
							_show_army_full_popup()
							return
						if GameState.spend_gold(sg_cost):
							SoundManager.play_sfx("coin")
							GameState.dwelling_stock["obelisk_guard"] -= 1
							GameState.add_units_to_army("stone_guardian", 1)
							popup_dialog.hide()
					)
				else:
					popup_text.text += "\n\n" + tr("Все стражи уже следуют за вами. Новые восстанут к следующей неделе.")
					popup_btn1.text = tr("Отойти")
					popup_btn1.pressed.connect(func(): popup_dialog.hide())
			else:
				popup_text.text = "Прикоснувшись к руническому монолиту, вы чувствуете, как тело наполняется силой легендарных героев прошлого!\n\n+2 к Атаке, +2 к Защите!"
				popup_btn1.text = "Принять силу предков"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("spell_cast")
					GameState.attack += 2
					GameState.defense += 2
					GameState.flags[obj_id] = true
					popup_dialog.hide()
				)

		"fairy_shrine":
			if GameState.quest_completed:
				popup_title.text = "Священная Роща Королевы Фей"
				popup_text.text = "Королева Фей тепло улыбается вам:\n\n«Свет и гармония вернулись в сказочный лес. Спасибо за верность и отвагу, сэр Аларик! Вы навсегда наш великий герой и спаситель!»"
				popup_btn1.text = "Благодарю вас!"
				for conn in popup_btn1.pressed.get_connections():
					popup_btn1.pressed.disconnect(conn.callable)
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
				var avail_pg: int = GameState.dwelling_stock.get("shrine_pegasus", 0)
				var pg_cost := 120
				if avail_pg > 0:
					popup_text.text += "\n\n" + tr("Крылатые пегасы готовы служить: %d шт. (по %d золота). Казна: %d.") % [avail_pg, pg_cost, GameState.gold]
					popup_btn2.visible = true
					popup_btn2.text = tr("Нанять пегасов (%d за %d зол.)") % [avail_pg, avail_pg * pg_cost]
					for conn in popup_btn2.pressed.get_connections():
						popup_btn2.pressed.disconnect(conn.callable)
					popup_btn2.pressed.connect(func():
						if not GameState.can_add_units("royal_pegasus"):
							_show_army_full_popup()
							return
						if GameState.spend_gold(avail_pg * pg_cost):
							SoundManager.play_sfx("coin")
							GameState.dwelling_stock["shrine_pegasus"] -= avail_pg
							GameState.add_units_to_army("royal_pegasus", avail_pg)
							popup_dialog.hide()
					)
				else:
					popup_btn2.visible = false
				_show_popup_dialog()
				return
			elif GameState.has_fairy_crown:
				SoundManager.play_sfx("victory")
				GameState.add_gold(2000)
				GameState.add_xp(2000)
				var ch1_granted := [GameState.grant_units("griffin", 8), GameState.grant_units("royal_pegasus", 4)]
				GameState.quest_completed = true
				GameState.unlock_feat("ch1_done")
				_update_hud()
				_update_quest_hud()
				
				victory_title.text = "👑 ПОБЕДА В ГЛАВЕ 1: ЗАЧАРОВАННЫЙ ЛЕС! 👑"
				victory_text.text = tr("Королева Фей со слезами радости принимает священный Венец из рук сэра Аларика!\n\nИзумрудный свет озаряет древний лес, рассеивая последние чары тьмы. Но тревожные вести приходят из Топей Скорби: Древний Лич поднимает армии нежити!\n\n★ ИТОГИ ГЛАВЫ 1: ★\n• Дней в походе: %d\n• Золото в казне: %d монет\n• Уровень Героя: %d (%s)\n• Награда Королевы: 8 Королевских Грифонов!\n\nГотовы ли вы выступить во вторую главу кампании?") % [
					GameState.day, GameState.gold, GameState.level, tr(GameState.hero_title)
				]
				victory_text.text += _granted_note(ch1_granted)
				victory_continue_btn.text = "⚔ В поход: Глава 2 (Проклятые Топи) ⚔"
				victory_dialog.move_to_front()
				victory_dialog.show()
				return
			else:
				popup_title.text = "Священная Роща Королевы Фей"
				popup_text.text = "Королева Фей со скорбью в голосе молвит:\n\n«Атаман разбойников украл наш священный Венец... Без него наш народ слабеет, а деревья чахнут.\nУмоляю вас, верните Венец из лагеря атамана на востоке!»"
				popup_btn1.text = "Я найду его!"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
				_show_popup_dialog()
				return

		"witch_hut":
			popup_title.text = "Хижина Болотной Ведьмы"
			if GameState.quest_completed:
				popup_text.text = "«Слава паладину! Топи снова чисты от скверны нежити!»"
				popup_btn1.text = "Поклониться"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			elif GameState.flags.get("witch_hut_visited", false):
				popup_text.text = "«Костяные Врата ждут вас, паладин! Разрушьте цитадель Лича на востоке!»"
				popup_btn1.text = "Я в пути!"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			else:
				popup_title.text = "Квест: Проклятые Топи"
				popup_text.text = "Болотная ведунья мешает зелье в котле:\n\n«Приветствую, сэр Аларик! Древний Лич восстал из затонувших склепов и погрузил край в вечный туман. Он запер перевал Костяными Вратами.\n\nВозьмите этот Костяной Ключ! Пробейтесь через нежить, уничтожьте Лича и очистите древний Алтарь Друидов!»"
				popup_btn1.text = "Принять Костяной Ключ"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("victory")
					GameState.flags["witch_hut_visited"] = true
					GameState.has_gate_key = true
					popup_dialog.hide()
				)

		"bone_gate":
			popup_title.text = "Костяные Врата Некрополя"
			if GameState.flags.get("bone_gate_opened", false):
				popup_text.text = "Врата из гигантских ребер распахнуты. Путь свободен!"
				popup_btn1.text = "Вперед"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			elif GameState.has_gate_key:
				popup_text.text = "Вы применяете Костяной Ключ ведьмы. Останки со скрежетом расходятся в стороны!\n\nПроход к Цитадели Лича открыт!"
				popup_btn1.text = "Пройти через врата"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("sword_hit")
					GameState.flags["bone_gate_opened"] = true
					popup_dialog.hide()
				)
			else:
				popup_text.text = "Зловещие Костяные Врата наглухо сомкнуты. От них веет смертельным холодом.\n\nВам нужен Костяной Ключ! (Посетите Хижину Болотной Ведьмы на юго-западе)."
				popup_btn1.text = "Отступить"
				popup_btn1.pressed.connect(func():
					world_view.hero_cell = Vector2i(13, 11)
					world_view.hero_pixel_pos = world_view.cell_to_pixel(Vector2i(13, 11))
					world_view.queue_redraw()
					GameState.hero_cell = Vector2i(13, 11)
					popup_dialog.hide()
				)

		"dragon_gate":
			popup_title.text = "Огненные Врата Ущелья"
			if GameState.flags.get("dragon_gate_opened", false):
				popup_text.text = "Бронзовые створки распахнуты. Дорога на Пик Дракона свободна!"
				popup_btn1.text = "В путь"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			else:
				popup_text.text = "Перед вами массивные Огненные Врата. Руны вспыхивают ярким светом под вашей рукой, и тяжелые створки распахиваются!"
				popup_btn1.text = "Пройти к логову Дракона"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("sword_hit")
					GameState.flags["dragon_gate_opened"] = true
					popup_dialog.hide()
				)

		"upgrade_altar":
			popup_title.text = "Алтарь Преображения Войск"
			var upgrade_slot = -1
			var upgrade_name = ""
			var upgrade_cost = 0
			for idx in range(GameState.player_army.size()):
				var slot = GameState.player_army[idx]
				var udata = UnitData.get_unit(slot["unit_id"])
				var up_to = udata.get("upgrade_to", "")
				if up_to != "":
					upgrade_slot = idx
					var next_udata = UnitData.get_unit(up_to)
					var cost_each = 15 if udata.tier <= 2 else 35
					upgrade_cost = cost_each * slot["count"]
					upgrade_name = tr("Улучшить %s -> %s (%d шт. за %d зол.)") % [
						tr(udata.name), tr(next_udata.name), slot["count"], upgrade_cost
					]
					break
			if upgrade_slot == -1:
				popup_text.text = "Священное сияние окутывает алтарь.\n\nВсе отряды вашего войска уже достигли высшей ступени развития!"
				popup_btn1.text = "Поклониться"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			else:
				popup_text.text = tr("Алтарь позволяет обучить ваших воинов тайным боевым искусствам:\n\n• Феи получают Двойной Выстрел (стреляют дважды за раунд!)\n• Грифоны получают Бесконечный Отпор на все атаки врагов!\n\nКазна: %d золота") % GameState.gold
				if GameState.gold >= upgrade_cost:
					popup_btn1.text = upgrade_name
					var target_slot = upgrade_slot
					popup_btn1.pressed.connect(func():
						if GameState.upgrade_army_unit(target_slot):
							SoundManager.play_sfx("victory")
							_update_hud()
							popup_dialog.hide()
					)
				else:
					popup_btn1.text = tr("Недостаточно золота (нужно %d зол.)") % upgrade_cost
					popup_btn1.pressed.connect(func(): popup_dialog.hide())

		"crypt":
			popup_title.text = "Затонувший Склеп"
			if GameState.flags.get(obj_id, false):
				popup_text.text = "Древний склеп пуст."
				popup_btn1.text = "Отойти"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			else:
				popup_text.text = "В глубине склепа вы находите драгоценные реликвии древних времен!"
				popup_btn1.text = "Забрать сокровища (+1200 золота)"
				popup_btn2.visible = true
				popup_btn2.text = "Изучить надгробные руны (+800 опыта)"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("coin")
					GameState.add_gold(1200)
					GameState.flags[obj_id] = true
					popup_dialog.hide()
				)
				popup_btn2.pressed.connect(func():
					SoundManager.play_sfx("victory")
					GameState.add_xp(800)
					GameState.flags[obj_id] = true
					popup_dialog.hide()
				)

		"forge":
			popup_title.text = "Кузница Горных Владык"
			if GameState.flags.get(obj_id, false):
				popup_text.text = "Горн тихо потрескивает. Кузнецы уже оснастили ваше войско."
				popup_btn1.text = "Продолжить путь"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			else:
				popup_text.text = "Мастера кузнечного дела перековывают ваши доспехи и мечи!\n\n+2 к Атаке, +2 к Защите паладина!"
				popup_btn1.text = "Принять работу кузнецов"
				popup_btn1.pressed.connect(func():
					SoundManager.play_sfx("sword_hit")
					GameState.attack += 2
					GameState.defense += 2
					GameState.flags[obj_id] = true
					popup_dialog.hide()
				)

		"lich_boss":
			if GameState.flags.get("lich_defeated", false) or GameState.flags.get(obj_id, false):
				world_view.remove_object_by_id(obj_id)
				popup_dialog.hide()
				return
			popup_title.text = "Цитадель Древнего Лича"
			popup_text.text = "Перед вами оплот черного колдовства!\nДревний Лич поднимает легион скелетов и болотных зомби!\n\nОни охраняют Перстень Архимага!"
			popup_btn1.text = "⚔ СОКРУШИТЬ ЛИЧА!"
			popup_btn1.pressed.connect(func():
				SoundManager.play_sfx("sword_hit")
				_start_battle("lich_boss")
			)
			popup_btn2.visible = true
			popup_btn2.text = "⚡ Быстрый бой"
			popup_btn2.pressed.connect(func(): _execute_quick_combat("lich_boss"))

		"dragon_boss":
			if GameState.flags.get("dragon_defeated", false) or GameState.flags.get(obj_id, false):
				world_view.remove_object_by_id(obj_id)
				popup_dialog.hide()
				return
			popup_title.text = "Пик Красного Дракона"
			popup_text.text = "Перед вами владыка пламени — легендарный Красный Дракон!\nВоздух дрожит от нестерпимого жара!\n\nЭто финальная битва за судьбу Королевства!"
			popup_btn1.text = "⚔ БРОСИТЬ ВЫЗОВ ДРАКОНУ!"
			popup_btn1.pressed.connect(func():
				SoundManager.play_sfx("sword_hit")
				_start_battle("dragon_boss")
			)
			popup_btn2.visible = true
			popup_btn2.text = "⚡ Быстрый бой"
			popup_btn2.pressed.connect(func(): _execute_quick_combat("dragon_boss"))

		"druid_altar":
			if GameState.quest_completed:
				popup_title.text = "Алтарь Очищения Топей"
				popup_text.text = "Друиды благодарят сэра Аларика:\n\n«Спасибо за избавление, паладин! Проклятие снято навсегда!»"
				popup_btn1.text = "Слава Свету!"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
				_show_popup_dialog()
				return
			elif GameState.flags.get("lich_defeated", false):
				SoundManager.play_sfx("victory")
				GameState.add_gold(3000)
				GameState.add_xp(3000)
				var ch2_granted := [GameState.grant_units("druid", 8)]
				GameState.quest_completed = true
				GameState.unlock_feat("ch2_done")
				_update_hud()
				_update_quest_hud()
				victory_title.text = "👑 ПОБЕДА В ГЛАВЕ 2: ПРОКЛЯТЫЕ ТОПИ! 👑"
				victory_text.text = tr("Древний Лич развеян в прах, и животворный свет возвращается в болота!\n\n★ ИТОГИ ГЛАВЫ 2: ★\n• Дней в походе: %d\n• Золото в казне: %d монет\n• Уровень Героя: %d\n• Награда: Перстень Архимага и отряд Друидов!\n\nГорные вестники приносят тревожную весть: на Пике Дракона пробудился древний властелин огня!") % [
					GameState.day, GameState.gold, GameState.level
				]
				victory_text.text += _granted_note(ch2_granted)
				victory_continue_btn.text = "⚔ В поход: Глава 3 (Пик Дракона) ⚔"
				victory_dialog.show()
				return
			else:
				popup_title.text = "Алтарь Очищения Топей"
				popup_text.text = "Алтарь осквернен темными чарами. Уничтожьте Лича в Цитадели на востоке (28, 11)!"
				popup_btn1.text = "Я сокрушу его!"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
				_show_popup_dialog()
				return

		"royal_citadel", "dragon_altar":
			if GameState.quest_completed:
				popup_title.text = "Королевская Цитадель"
				popup_text.text = "«Да здравствует сэр Аларик, величайший защитник Королевства!»"
				popup_btn1.text = "Благодарю!"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
				_show_popup_dialog()
				return
			elif GameState.flags.get("dragon_defeated", false):
				SoundManager.play_sfx("victory")
				GameState.add_gold(5000)
				GameState.add_xp(5000)
				GameState.quest_completed = true
				GameState.unlock_feat("ch3_done")
				_update_hud()
				_update_quest_hud()
				victory_title.text = "👑 ВЕЛИКИЙ ТРИУМФ ВСЕЙ КАМПАНИИ! 👑"
				victory_text.text = tr("Красный Дракон повержен! Владыка небес склонился перед доблестью паладина Аларика!\n\nВсе угрозы Королевству устранены, реликвии возвращены, а мир воцарился во всех землях на тысячу лет!\n\n★ ИТОГИ ВЕЛИКОЙ КАМПАНИИ: ★\n• Пройдено глав: 3 из 3\n• Дней в походе: %d\n• Золото в казне: %d\n• Уровень Героя: %d\n• Артефакты: Полный комплект реликвий Королевства!\n\nКороль жалует вам высший титул «Маршал Королевства»!") % [
					GameState.day, GameState.gold, GameState.level
				]
				victory_continue_btn.text = "Завершить кампанию"
				victory_dialog.move_to_front()
				victory_dialog.show()
				return
			else:
				popup_title.text = "Королевская Цитадель"
				popup_text.text = "Небо объято багровым заревом. Сразите Красного Дракона на Пике (28, 11)!"
				popup_btn1.text = "Я одолею дракона!"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
				_show_popup_dialog()
				return

	_show_popup_dialog()

func _show_popup_dialog() -> void:
	# Обращение по классу героя: сэр Аларик / леди Элеонора / мастер Торн
	popup_text.text = popup_text.text.replace("сэр Аларик", GameState.hero_form())
	popup_dialog.move_to_front()
	popup_dialog.visible = true

func _execute_quick_combat(battle_id: String, on_victory: Callable = Callable()) -> void:
	# 1. Determine enemy army — единый источник: data/encounters.json
	var enemy_army: Array[Dictionary] = []
	var battle_name = "Вражеский отряд"
	var qc_enc := EncounterData.get_encounter(battle_id)
	var qc_diff := GameState.get_difficulty_multipliers(GameState.campaign_difficulty)
	# Chapter 1 Encounters
	if qc_enc.is_empty():
		qc_enc = EncounterData.get_default_for_chapter(GameState.current_chapter)
	for qe in qc_enc["enemies"]:
		enemy_army.append({"unit_id": qe["unit_id"], "count": maxi(1, int(round(qe["count"] * float(qc_diff["enemy"]))))})
	var qc_log: String = tr(qc_enc["log"])
	battle_name = qc_log.split("!")[0] if "!" in qc_log else qc_log

	# 2. Calculate combat power — квадратичный закон Ланчестера (PR #4):
	# сила = sqrt(sum(HP) * sum(урона за раунд)); атака/защита +-5% за очко,
	# стрелки без ответа x1.3, двойной выстрел x2, Сила Магии героя +3% за очко
	var player_power: float = _army_power(GameState.player_army, true)
	var enemy_power: float = _army_power(enemy_army, false)

	# 3. Resolve Outcome
	popup_dialog.hide()
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	for conn in popup_btn2.pressed.get_connections():
		popup_btn2.pressed.disconnect(conn.callable)

	if player_power >= enemy_power:
		SoundManager.play_sfx("victory")
		# Потери победителя: 1 - sqrt(1 - (сила врага / своя сила)^2), поровну по отрядам
		var power_ratio: float = enemy_power / maxf(player_power, 1.0)
		var loss_ratio: float = clampf(1.0 - sqrt(maxf(0.0, 1.0 - power_ratio * power_ratio)), 0.02, 0.9)
		var casualties_desc = ""
		
		# Apply losses
		for idx in range(GameState.player_army.size()):
			var st = GameState.player_army[idx]
			var lost = int(round(float(st["count"]) * loss_ratio))
			lost = mini(lost, max(0, st["count"] - 1))
			st["count"] -= lost
			if lost > 0:
				var u = UnitData.get_unit(st["unit_id"])
				casualties_desc += tr("• %s: потеряно %d\n") % [tr(u.get("name", "Воины")), lost]
		if casualties_desc == "":
			casualties_desc = "• Без потерь! Безупречная тактическая победа!\n"

		var reward_gold = 750
		var reward_xp = 550
		var artifact_msg = ""
		
		if battle_id == "bandit_boss":
			reward_gold = 1500
			reward_xp = 1200
			GameState.has_fairy_crown = true
			if not GameState.inventory_artifacts.has("crown_fairy") and not GameState.equipped_artifacts.values().has("crown_fairy"):
				GameState.inventory_artifacts.append("crown_fairy")
			artifact_msg = "\n👑 ПОЛУЧЕН ВЕНЕЦ КОРОЛЕВЫ ФЕЙ!"
		elif battle_id == "lich_boss":
			reward_gold = 2500
			reward_xp = 2200
			GameState.flags["lich_defeated"] = true
			if not GameState.inventory_artifacts.has("ring_arcana") and not GameState.equipped_artifacts.values().has("ring_arcana"):
				GameState.inventory_artifacts.append("ring_arcana")
			artifact_msg = "\n💍 ПОЛУЧЕН ПЕРСТЕНЬ АРХИМАГА!"
		elif battle_id == "dragon_boss":
			reward_gold = 5000
			reward_xp = 4000
			GameState.flags["dragon_defeated"] = true
			if not GameState.inventory_artifacts.has("armor_chitin") and not GameState.equipped_artifacts.values().has("armor_chitin"):
				GameState.inventory_artifacts.append("armor_chitin")
			artifact_msg = "\n🦺 ПОЛУЧЕН ПАНЦИРЬ ДРЕВНЕГО СТРАЖА!"

		GameState.add_gold(reward_gold)
		GameState.add_xp(reward_xp)
		var qc_kinds: Array = []
		for qst in GameState.player_army:
			if int(qst["count"]) > 0 and not qc_kinds.has(str(qst["unit_id"])):
				qc_kinds.append(str(qst["unit_id"]))
		for promo in GameState.add_veteran_wins(qc_kinds):
			artifact_msg += "\n" + tr("🎖 %s становятся ветеранами %s\n+%d к атаке и защите!") % [
				tr(UnitData.get_unit(promo["unit_id"]).get("name", "")), GameState.veteran_marks(promo["rank"]), promo["rank"]
			]
		GameState.flags[battle_id] = true
		world_view.remove_object_by_id(battle_id)
		GameState.save_game()
		
		_update_hud()
		_update_quest_hud()

		if battle_id == "bandit_boss":
			world_view._reveal_fog(Vector2i(27, 4), 5)
			world_view.queue_redraw()
			_show_crown_recovered_popup()
		elif battle_id == "lich_boss":
			world_view._reveal_fog(Vector2i(27, 4), 6)
			world_view.queue_redraw()
			_show_lich_defeated_popup()
		elif battle_id == "dragon_boss":
			world_view._reveal_fog(Vector2i(27, 4), 6)
			world_view.queue_redraw()
			_show_dragon_defeated_popup()
		else:
			popup_title.text = "⚡ БЫСТРЫЙ БОЙ: ПОБЕДА!"
			popup_text.text = tr("Ваша армия стремительно сокрушила врага (%s)!\n\nПотери войска:\n%s\nПолучено награды:\n💰 Золото: +%d\n⭐ Опыт: +%d%s") % [
				battle_name, casualties_desc, reward_gold, reward_xp, artifact_msg
			]
			if on_victory.is_valid():
				popup_btn1.text = "Открыть сундук!"
				popup_btn1.pressed.connect(func():
					popup_dialog.hide()
					on_victory.call()
				)
			else:
				popup_btn1.text = "Великолепно!"
				popup_btn1.pressed.connect(func(): popup_dialog.hide())
			popup_btn2.visible = false
			_show_popup_dialog()
	else:
		SoundManager.play_sfx("click")
		popup_title.text = "⚠️ СИЛЫ НЕРАВНЫ!"
		popup_text.text = tr("Разведка докладывает: силы противника (%s) слишком велики для авторасчета без тяжелых потерь!\n\nРекомендуется провести бой лично на арене или нанять подкрепление.") % battle_name
		popup_btn1.text = "Понятно"
		popup_btn1.pressed.connect(func(): popup_dialog.hide())
		popup_btn2.visible = false
		_show_popup_dialog()

## Сброс обработчиков кнопок попапа: награды не должны выдаваться повторно (PR #2).
func _reset_popup_buttons() -> void:
	for btn in [popup_btn1, popup_btn2]:
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		popup_btn2.visible = false

func _show_army_full_popup() -> void:
	SoundManager.play_sfx("click")
	popup_title.text = tr("Войско полно")
	popup_text.text = tr("В войске нет свободных слотов. Объедините или разделите отряды в панели «Войско Героя».")
	popup_btn1.text = tr("Понятно")
	_reset_popup_buttons()
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	popup_btn2.visible = false
	_show_popup_dialog()

## Пояснение к подаренным отрядам, если они не встали в войско своим стеком (GameState.grant_units).
func _granted_note(results: Array) -> String:
	var lines: Array[String] = []
	for r in results:
		if not (r is Dictionary) or r.is_empty():
			continue
		var from_name := tr(str(UnitData.get_unit(str(r.get("from", ""))).get("name", "")))
		var into: String = str(r.get("unit_id", ""))
		if int(r.get("gold", 0)) > 0:
			lines.append(tr("Отряду «%s» не нашлось места в войске — вместо него казна получает %d золота.") % [from_name, int(r["gold"])])
		elif into != "" and into != str(r.get("from", "")):
			lines.append(tr("%s влились в отряд «%s».") % [from_name, tr(str(UnitData.get_unit(into).get("name", "")))])
	return "" if lines.is_empty() else "\n\n" + "\n".join(lines)

## Сила армии для быстрого боя по квадратичному закону Ланчестера (PR #4).
func _army_power(army: Array, is_player: bool) -> float:
	var hero_att: int = GameState.get_total_attack() if is_player else 0
	var hero_def: int = GameState.get_total_defense() if is_player else 0
	var hp_total := 0.0
	var dmg_total := 0.0
	for stack in army:
		var u: Dictionary = UnitData.get_unit(stack["unit_id"])
		if u.is_empty():
			continue
		var count := float(stack["count"])
		var vet: int = GameState.veteran_rank(str(stack["unit_id"])) if is_player else 0
		hp_total += count * float(u.get("max_hp", 10)) * (1.0 + (int(u.get("defense", 0)) + hero_def + vet) * 0.05)
		var dmg := count * (float(u.get("min_dmg", 1)) + float(u.get("max_dmg", 1))) / 2.0 * (1.0 + (int(u.get("attack", 4)) + hero_att + vet) * 0.05)
		if u.get("is_ranged", false):
			dmg *= 1.3
		if u.get("double_shot", false):
			dmg *= 2.0
		dmg_total += dmg
	return sqrt(hp_total * dmg_total)

func _is_any_modal_open() -> bool:
	if world_view.is_moving:
		return true
	for d in [popup_dialog, split_dialog, victory_dialog, hero_dialog, level_dialog, confirm_end_day_dialog, pause_dialog, $CanvasLayer/SpellbookDialog]:
		if d != null and is_instance_valid(d) and d.visible:
			return true
	return false

func _update_hud() -> void:
	if name_label:
		name_label.text = tr("%s (ур. %d)") % [tr(GameState.hero_name), GameState.level]
	var portrait_node = $CanvasLayer/TopHUD/Portrait as TextureRect
	if portrait_node and ResourceLoader.exists(GameState.hero_portrait):
		portrait_node.texture = load(GameState.hero_portrait)
	gold_label.text = tr("🪙 %d") % GameState.gold
	mana_label.text = tr("🔮 %d/%d") % [GameState.current_mana, GameState.max_mana]
	day_label.text = tr("Гл. %d • День %d") % [GameState.current_chapter, GameState.day]
	mp_label.text = tr("Ход: %d/%d") % [GameState.move_points, GameState.max_move_points]
	mp_bar.max_value = GameState.max_move_points
	mp_bar.value = GameState.move_points
	
	# Update left army panel (rebuild only when its contents actually changed)
	var army_sig := str(selected_army_slot) + ":"
	for slot in GameState.player_army:
		army_sig += str(slot["unit_id"]) + ":" + str(slot["count"]) + "|"
	if army_sig == _army_panel_sig:
		return
	_army_panel_sig = army_sig

	for child in army_container.get_children():
		child.queue_free()
		
	if army_title:
		if selected_army_slot != -1 and selected_army_slot < GameState.player_army.size():
			var sel_udata = UnitData.get_unit(GameState.player_army[selected_army_slot]["unit_id"])
			army_title.text = tr("✦ %s: ОБМЕН ✦") % tr(sel_udata.get("name", "ОТРЯД")).to_upper()
			army_title.add_theme_color_override("font_color", Color(0.7, 0.32, 0.05))
		else:
			selected_army_slot = -1
			army_title.text = "Войско Героя"
			army_title.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05))
		
	for i in range(GameState.player_army.size()):
		var slot = GameState.player_army[i]
		var udata = UnitData.get_unit(slot["unit_id"])
		var slot_idx = i

		# Card container for selection styling and clicking
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 48)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.tooltip_text = "Нажмите, чтобы выбрать для обмена местами (или используйте ▲▼)"

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4

		if selected_army_slot == slot_idx:
			style.bg_color = Color(1.0, 0.88, 0.4, 0.35)
			style.border_color = Color(0.95, 0.75, 0.1, 1.0)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0, 0, 0, 0.04)
			style.border_color = Color(0.55, 0.4, 0.25, 0.35)
			style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", style)

		# Row content
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_PASS

		# Icon
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		var tpath = udata.get("token_path", "")
		if ResourceLoader.exists(tpath):
			icon.texture = load(tpath)
		row.add_child(icon)

		# Name and count
		var lbl = Label.new()
		lbl.custom_minimum_size = Vector2(75, 0)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		var font_col = Color(0.45, 0.2, 0.0) if selected_army_slot == slot_idx else Color(0.2, 0.12, 0.05)
		lbl.add_theme_color_override("font_color", font_col)
		lbl.add_theme_font_size_override("font_size", 13)
		var prefix = "★ " if selected_army_slot == slot_idx else ""
		lbl.text = "%s%s\n× %d" % [prefix, tr(udata.get("name", "")), slot["count"]]
		var vet_rank := GameState.veteran_rank(str(slot["unit_id"]))
		if vet_rank > 0:
			lbl.text += "  " + GameState.veteran_marks(vet_rank)
			lbl.tooltip_text = tr("Ветераны: +%d к атаке и защите (побед: %d)") % [vet_rank, int(GameState.veteran_wins.get(str(slot["unit_id"]), 0))]
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(lbl)

		# Up button ▲
		if slot_idx > 0:
			var up_btn = Button.new()
			up_btn.text = "▲"
			up_btn.tooltip_text = "Поднять выше"
			up_btn.custom_minimum_size = Vector2(26, 28)
			up_btn.pressed.connect(func():
				GameState.swap_army_slots(slot_idx, slot_idx - 1)
				SoundManager.play_sfx("click")
				selected_army_slot = -1
				_update_hud()
			)
			row.add_child(up_btn)

		# Down button ▼
		if slot_idx < GameState.player_army.size() - 1:
			var down_btn = Button.new()
			down_btn.text = "▼"
			down_btn.tooltip_text = "Опустить ниже"
			down_btn.custom_minimum_size = Vector2(26, 28)
			down_btn.pressed.connect(func():
				GameState.swap_army_slots(slot_idx, slot_idx + 1)
				SoundManager.play_sfx("click")
				selected_army_slot = -1
				_update_hud()
			)
			row.add_child(down_btn)

		# Split button (if count > 1 and army has free slot < 5)
		if slot["count"] > 1 and GameState.player_army.size() < 5:
			var split_btn = Button.new()
			split_btn.text = "1/2"
			split_btn.tooltip_text = "Разделить отряд"
			split_btn.custom_minimum_size = Vector2(34, 28)
			split_btn.pressed.connect(func(): _open_split_dialog(slot_idx))
			row.add_child(split_btn)

		# Merge button (if another slot has same unit_id)
		var other_slot = -1
		for j in range(GameState.player_army.size()):
			if j != slot_idx and GameState.player_army[j]["unit_id"] == slot["unit_id"]:
				other_slot = j
				break
		if other_slot != -1 and slot_idx < other_slot:
			var merge_btn = Button.new()
			merge_btn.text = "Слить"
			merge_btn.tooltip_text = "Объединить одинаковые отряды"
			merge_btn.custom_minimum_size = Vector2(46, 28)
			var s_a = slot_idx
			var s_b = other_slot
			merge_btn.pressed.connect(func():
				SoundManager.play_sfx("coin")
				GameState.merge_stacks(s_a, s_b)
				selected_army_slot = -1
				_update_hud()
			)
			row.add_child(merge_btn)

		# Click on card to select / swap (HoMM style)
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if selected_army_slot == -1:
					selected_army_slot = slot_idx
					SoundManager.play_sfx("click")
					_update_hud()
				elif selected_army_slot == slot_idx:
					selected_army_slot = -1
					SoundManager.play_sfx("click")
					_update_hud()
				else:
					var src_idx = selected_army_slot
					var dest_idx = slot_idx
					selected_army_slot = -1
					if GameState.player_army[src_idx]["unit_id"] == GameState.player_army[dest_idx]["unit_id"]:
						GameState.merge_stacks(dest_idx, src_idx)
						SoundManager.play_sfx("victory")
					else:
						GameState.swap_army_slots(src_idx, dest_idx)
						SoundManager.play_sfx("click")
					_update_hud()
		)

		card.add_child(row)
		army_container.add_child(card)

func _open_split_dialog(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= GameState.player_army.size():
		return
	SoundManager.play_sfx("page_turn")
	current_split_slot = slot_idx
	var slot = GameState.player_army[slot_idx]
	var udata = UnitData.get_unit(slot["unit_id"])
	split_info.text = tr("Отряд: %s (всего: %d)") % [tr(udata.name), slot["count"]]
	split_slider.min_value = 1
	split_slider.max_value = slot["count"] - 1
	split_slider.value = 1
	split_value_lbl.text = "Выделить в новый отряд: 1"
	split_dialog.move_to_front()
	split_dialog.show()

func _on_split_slider_changed(val: float) -> void:
	split_value_lbl.text = tr("Выделить в новый отряд: %d") % int(val)

func _on_confirm_split() -> void:
	if current_split_slot < 0 or current_split_slot >= GameState.player_army.size():
		split_dialog.hide()
		return
	var count = int(split_slider.value)
	SoundManager.play_sfx("coin")
	GameState.split_stack(current_split_slot, count)
	split_dialog.hide()
	_update_hud()

func _on_end_day_pressed() -> void:
	if world_view.is_moving:
		return
	if confirm_end_day_dialog and confirm_end_day_dialog.visible:
		return
	if GameState.move_points > 0:
		SoundManager.play_sfx("page_turn")
		if confirm_end_day_prompt:
			confirm_end_day_prompt.text = tr("У героя еще остались очки хода (%d/%d).\nВы действительно хотите завершить день?") % [
				GameState.move_points, GameState.max_move_points
			]
		if confirm_end_day_dialog:
			confirm_end_day_dialog.move_to_front()
			confirm_end_day_dialog.show()
		return
	_execute_end_day()

func _execute_end_day() -> void:
	_clear_planned_route()
	SoundManager.play_sfx("click")
	GameState.next_day()
	world_view.queue_redraw()
	_show_day_tip()
	if GameState.day % 7 == 1:
		_spawn_merchant()
	if GameState.last_astrologers_event.size() > 0:
		_show_astrologers_popup(GameState.last_astrologers_event)

func _show_astrologers_popup(ev: Dictionary) -> void:
	SoundManager.play_sfx("victory")
	popup_btn1.visible = true
	popup_btn2.visible = false
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	for conn in popup_btn2.pressed.get_connections():
		popup_btn2.pressed.disconnect(conn.callable)
	popup_title.text = "📜 АСТРОЛОГИ ОБЪЯВЛЯЮТ... 📜"
	popup_text.text = tr(ev.get("description", "")) + _granted_note([ev.get("granted", {})])
	popup_btn1.text = "Да будет так!"
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

func _show_crown_recovered_popup() -> void:
	SoundManager.play_sfx("victory")
	popup_btn1.visible = true
	popup_btn2.visible = false
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	for conn in popup_btn2.pressed.get_connections():
		popup_btn2.pressed.disconnect(conn.callable)
	popup_title.text = "★ ВЕНЕЦ КОРОЛЕВЫ ФЕЙ ДОБЫТ! ★"
	popup_text.text = "Атаман разбойников повержен, и вся долина избавлена от зла!\n\nСвященный Венец озаряет ваши доспехи древним золотым светом!\n\nСкорее доставьте Венец Королеве Фей в Священную Рощу (27, 4) на северо-востоке для празднования великой победы и завершения кампании!"
	popup_btn1.text = "В Священную Рощу!"
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

func _show_lich_defeated_popup() -> void:
	SoundManager.play_sfx("victory")
	popup_btn1.visible = true
	popup_btn2.visible = false
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	for conn in popup_btn2.pressed.get_connections():
		popup_btn2.pressed.disconnect(conn.callable)
	popup_title.text = "★ ДРЕВНИЙ ЛИЧ СОКРУШЕН! ★"
	popup_text.text = "Черный владыка топей обращен в прах! Перстень Архимага в ваших руках!\n\nСпешите к Алтарю Друидов (27, 4) на северо-востоке, чтобы завершить очищение края и получить благословение природы!"
	popup_btn1.text = "К Алтарю Друидов!"
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

func _show_dragon_defeated_popup() -> void:
	SoundManager.play_sfx("victory")
	popup_btn1.visible = true
	popup_btn2.visible = false
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	for conn in popup_btn2.pressed.get_connections():
		popup_btn2.pressed.disconnect(conn.callable)
	popup_title.text = "★ КРАСНЫЙ ДРАКОН ПОВЕРЖЕН! ★"
	popup_text.text = "Легендарный владыка пламени повержен! Панцирь Древнего Стража сияет на ваших плечах!\n\nВступайте в Королевскую Цитадель (27, 4) для коронации и триумфального завершения Великой Кампании!"
	popup_btn1.text = "В Королевскую Цитадель!"
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

func _on_victory_continue_pressed() -> void:
	victory_dialog.hide()
	if GameState.current_chapter == 1:
		GameState.start_chapter(2)
		GameState.save_game()
		get_tree().change_scene_to_file("res://src/world/world_map.tscn")
	elif GameState.current_chapter == 2:
		GameState.start_chapter(3)
		GameState.save_game()
		get_tree().change_scene_to_file("res://src/world/world_map.tscn")
	else:
		GameState.reset()
		get_tree().change_scene_to_file("res://src/main.tscn")

func _open_spellbook() -> void:
	var book = $CanvasLayer/SpellbookDialog
	var subtitle = book.get_node_or_null("Parchment/Margin/MainVBox/ManaSubtitle")
	if subtitle:
		var sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
		subtitle.text = tr("Запас маны: %d / %d 🔮  •  Сила Магии: %d") % [GameState.current_mana, GameState.max_mana, sp]
	
	var scry_btn = book.get_node_or_null("Parchment/Margin/MainVBox/Scroll/ContentVBox/AdvCardsHBox/ScryCard/CardVBox/ScryBtn")
	if scry_btn:
		scry_btn.disabled = GameState.current_mana < 10
		scry_btn.text = "🔮 Сотворить: Око Орла (10 🔮)" if not scry_btn.disabled else "❌ Мало маны (нужно 10 🔮)"
		
	var rest_btn = book.get_node_or_null("Parchment/Margin/MainVBox/Scroll/ContentVBox/AdvCardsHBox/RestCard/CardVBox/RestBtn")
	if rest_btn:
		rest_btn.disabled = GameState.current_mana < 15
		rest_btn.text = "🌿 Сотворить: Благодать (15 🔮)" if not rest_btn.disabled else "❌ Мало маны (нужно 15 🔮)"
		
	var combat_grid = book.get_node_or_null("Parchment/Margin/MainVBox/Scroll/ContentVBox/CombatGrid")
	if combat_grid:
		for c in combat_grid.get_children():
			c.queue_free()
		for sp_id in GameState.learned_spells:
			var sdata = SpellData.get_spell(sp_id)
			if sdata.get("category", "") != "combat":
				continue
			var p = PanelContainer.new()
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pv = VBoxContainer.new()
			pv.add_theme_constant_override("separation", 2)
			p.add_child(pv)
			
			var stitle = Label.new()
			stitle.text = tr("✦ %s (%d 🔮)") % [sdata.name, sdata.mana_cost]
			stitle.add_theme_font_size_override("font_size", 14)
			stitle.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
			pv.add_child(stitle)
			
			var sdesc = Label.new()
			sdesc.text = sdata.description
			sdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sdesc.add_theme_font_size_override("font_size", 12)
			sdesc.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15))
			pv.add_child(sdesc)
			
			combat_grid.add_child(p)
			
	book.move_to_front()
	book.show()

func _cast_scrying() -> void:
	if not GameState.spend_mana(10):
		SoundManager.play_sfx("click")
		return
	SoundManager.play_sfx("spell_cast")
	world_view._reveal_fog(world_view.hero_cell, 9)
	world_view.queue_redraw()
	_update_hud()
	$CanvasLayer/SpellbookDialog.hide()
	popup_title.text = "Око Орла"
	popup_text.text = "Великий магический взор пронзает пелену тумана! Окрестные земли и тайные тропы открыты вашему взору!"
	popup_btn1.text = "Превосходно!"
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

func _restorable_count() -> int:
	# та же логика, что у самого возвращения — включая отряды, павшие целиком
	return GameState.restorable_fallen_count()

func _cast_restoration() -> void:
	var can_restore := _restorable_count()
	if can_restore <= 0:
		SoundManager.play_sfx("click")
		popup_title.text = tr("Благодать Похода")
		popup_text.text = tr("«В боях никто не пал — возвращать некому. Приходите после сражений!»")
		popup_btn1.text = tr("Хорошо")
		_reset_popup_buttons()
		popup_btn1.pressed.connect(func(): popup_dialog.hide())
		_show_popup_dialog()
		return
	if not GameState.spend_mana(15):
		SoundManager.play_sfx("click")
		return
	SoundManager.play_sfx("spell_cast")
	var res: Dictionary = GameState.restore_fallen_units()
	var restored: int = int(res["restored"])
	GameState.state_changed.emit()
	_update_hud()
	$CanvasLayer/SpellbookDialog.hide()
	popup_title.text = tr("Благодать Похода")
	popup_text.text = tr("Священная энергия возвращает павших в боях в строй: %d воинов!") % restored
	popup_btn1.text = tr("Во славу Королевства!")
	_reset_popup_buttons()
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

## Клетка текущей сюжетной цели — для маркера на миникарте и стрелки у героя.
func _get_current_objective_cell() -> Vector2i:
	if GameState.quest_completed:
		return Vector2i(-99, -99)
	match GameState.current_chapter:
		2:
			if not GameState.flags.get("witch_hut_visited", false):
				return Vector2i(6, 17)
			elif not GameState.flags.get("bone_gate_opened", false):
				return Vector2i(14, 11)
			elif not GameState.flags.get("lich_defeated", false):
				return Vector2i(28, 11)
			return Vector2i(27, 4)
		3:
			if not GameState.flags.get("dragon_gate_opened", false):
				return Vector2i(14, 11)
			elif not GameState.flags.get("dragon_defeated", false):
				return Vector2i(28, 11)
			return Vector2i(27, 4)
		_:
			if not GameState.quest_forester_started:
				return Vector2i(7, 18)
			elif not GameState.flags.get("iron_gate_opened", false):
				return Vector2i(14, 11)
			elif not GameState.has_fairy_crown:
				return Vector2i(28, 11)
			return Vector2i(27, 4)

func _update_quest_hud() -> void:
	if not quest_label:
		return
	match GameState.current_chapter:
		2:
			if not GameState.flags.get("witch_hut_visited", false):
				quest_label.text = "Посетите Хижину Болотной Ведьмы (6, 17), чтобы получить Костяной Ключ."
			elif not GameState.flags.get("bone_gate_opened", false):
				quest_label.text = "Откройте Костяные Врата (14, 11) с помощью ключа ведьмы."
			elif not GameState.flags.get("lich_defeated", false):
				quest_label.text = "Сокрушите Древнего Лича в Цитадели (28, 11) на востоке топей!"
			elif not GameState.quest_completed:
				quest_label.text = "👑 ОЧИСТИТЕ ТОПИ! Посетите Алтарь Друидов (27, 4) для завершения Главы 2!"
			else:
				quest_label.text = "★ ГЛАВА 2 ЗАВЕРШЕНА! Проклятые топи очищены от скверны!"
		3:
			if not GameState.flags.get("dragon_gate_opened", false):
				quest_label.text = "Исследуйте огненный перевал и откройте Огненные Врата (14, 11)!"
			elif not GameState.flags.get("dragon_defeated", false):
				quest_label.text = "Сразитесь с Красным Драконом на вершине Пика (28, 11)!"
			elif not GameState.quest_completed:
				quest_label.text = "👑 ПОБЕДА! Доставьте трофеи в Королевскую Цитадель (27, 4)!"
			else:
				quest_label.text = "★ ВЕЛИКАЯ КАМПАНИЯ ЗАВЕРШЕНА! В Королевстве настал золотой век!"
		_:
			if not GameState.quest_forester_started:
				quest_label.text = "Посетите Хижину Лесника (7, 18) на юге, чтобы узнать о беде и получить Ключ от Врат."
			elif not GameState.flags.get("iron_gate_opened", false):
				quest_label.text = "Используйте Ключ Лесника, чтобы открыть Железные Врата (14, 11) в Долину."
			elif not GameState.has_fairy_crown:
				quest_label.text = "Сокрушите Атамана разбойников (28, 11) на востоке долины и верните похищенный Венец!"
			elif not GameState.quest_completed:
				quest_label.text = "👑 ВЕРНИТЕ ВЕНЕЦ! Доставьте реликвию Королеве Фей в Священную Рощу (27, 4)!"
			else:
				quest_label.text = "★ ГЛАВА 1 ЗАВЕРШЕНА! Отправляйтесь в Проклятые Топи (Глава 2)!"
	if world_view:
		world_view.objective_cell = _get_current_objective_cell()
		world_view.queue_redraw()


func _toggle_hero_profile() -> void:
	if hero_dialog.visible:
		hero_dialog.hide()
	else:
		_open_hero_profile()

func _open_hero_profile() -> void:
	SoundManager.play_sfx("page_turn")
	_update_hero_profile()
	hero_dialog.move_to_front()
	hero_dialog.show()

func _update_hero_profile() -> void:
	hero_dialog.get_node("Parchment/Title").text = tr("Герой: %s (%s)") % [tr(GameState.hero_name), tr(GameState.hero_title)]
	if hero_name_lbl:
		hero_name_lbl.text = GameState.hero_name
	hero_level_lbl.text = tr("Уровень: %d (Глава %d)") % [GameState.level, GameState.current_chapter]
	hero_xp_lbl.text = tr("Опыт: %d / %d") % [GameState.xp, GameState.next_level_xp]
	hero_xp_bar.max_value = GameState.next_level_xp
	hero_xp_bar.value = GameState.xp
	
	# Relics & Story Keys
	var relics: Array[String] = []
	if GameState.has_fairy_crown:
		relics.append("👑 Венец Королевы Фей")
	if GameState.has_gate_key:
		relics.append("🗝 Ключ от Врат")
	if GameState.flags.get("iron_gate_opened", false) or GameState.flags.get("bone_gate_opened", false):
		relics.append("⚔ Перевал открыт")
		
	if relics.is_empty():
		hero_relics_lbl.text = "• Нет сюжетных реликвий"
	else:
		hero_relics_lbl.text = "• " + "\n• ".join(relics)
		
	# Primary Attributes
	var tot_att = GameState.get_total_attack() if GameState.has_method("get_total_attack") else GameState.attack
	var att_bonus = tot_att - GameState.attack
	var att_str = (tr(" (+%d от снаряжения)") % att_bonus) if att_bonus > 0 else ""
	hero_att_lbl.text = tr("⚔️ Атака: %d (+%d%% урон)%s") % [tot_att, tot_att * 5, att_str]
	
	var tot_def = GameState.get_total_defense() if GameState.has_method("get_total_defense") else GameState.defense
	var def_bonus = tot_def - GameState.defense
	var def_str = (tr(" (+%d от снаряжения)") % def_bonus) if def_bonus > 0 else ""
	hero_def_lbl.text = tr("🛡️ Защита: %d (-%d%% урон)%s") % [tot_def, tot_def * 3, def_str]
	
	var tot_sp = GameState.get_total_spellpower() if GameState.has_method("get_total_spellpower") else GameState.spellpower
	var sp_bonus = tot_sp - GameState.spellpower
	var sp_str = (tr(" (+%d от снаряжения)") % sp_bonus) if sp_bonus > 0 else ""
	hero_sp_lbl.text = tr("🔮 Сила Магии: %d%s") % [tot_sp, sp_str]
	
	var tot_kn = GameState.get_total_knowledge() if GameState.has_method("get_total_knowledge") else GameState.knowledge
	hero_kn_lbl.text = tr("📜 Знание: %d (%d маны)") % [tot_kn, GameState.max_mana]
	
	# Set Synergy Bonus
	if hero_set_bonus_lbl:
		var set_res = ArtifactData.get_active_set_bonuses(GameState.equipped_artifacts)
		var titles: Array = set_res.get("active_titles", [])
		if titles.size() > 0:
			hero_set_bonus_lbl.text = "✦ " + "\n✦ ".join(titles)
		else:
			hero_set_bonus_lbl.text = ""

	# Mannequin Equipment Slots (Paper Doll)
	var slot_icons = {
		"relic": "👑\nШлем",
		"weapon": "⚔️\nОружие",
		"armor": "🦺\nДоспех",
		"shield": "🛡️\nЩит",
		"accessory": "💍\nКольцо",
		"boots": "👢\nОбувь"
	}
	for slot in ArtifactData.get_all_slot_names():
		var slot_btn = mannequin_box.get_node_or_null("Slot_" + slot)
		if not slot_btn:
			continue
		for conn in slot_btn.pressed.get_connections():
			slot_btn.pressed.disconnect(conn.callable)
			
		if GameState.equipped_artifacts.has(slot):
			var a_id = GameState.equipped_artifacts[slot]
			var art = ArtifactData.get_artifact(a_id)
			slot_btn.text = "%s\n%s" % [art.get("icon", "⚔"), tr(art.get("name", ""))]
			slot_btn.tooltip_text = tr("【%s】 %s\n%s\n\n(Клик — снять в рюкзак)") % [
				tr(ArtifactData.get_slot_title(slot)), tr(art.get("name", "")), tr(art.get("description", ""))
			]
			slot_btn.modulate = Color(1.0, 0.95, 0.7)
			var s = slot
			slot_btn.pressed.connect(func():
				SoundManager.play_sfx("coin")
				GameState.unequip_artifact(s)
				_update_hero_profile()
				_update_hud()
			)
		else:
			slot_btn.text = slot_icons.get(slot, "Пусто")
			slot_btn.tooltip_text = tr("Слот: %s (Свободен)\nВыберите артефакт в рюкзаке ниже") % tr(ArtifactData.get_slot_title(slot))
			slot_btn.modulate = Color(0.85, 0.85, 0.85, 0.85)

	# Backpack Inventory Grid
	if backpack_vbox:
		for ch in backpack_vbox.get_children():
			ch.queue_free()
			
		if GameState.inventory_artifacts.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "• Рюкзак пуст (ищите реликвии на карте)"
			empty_lbl.add_theme_font_size_override("font_size", 13)
			empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.28, 0.15))
			backpack_vbox.add_child(empty_lbl)
		else:
			for a_id in GameState.inventory_artifacts:
				var art = ArtifactData.get_artifact(a_id)
				var btn = Button.new()
				btn.text = tr("Надеть: %s %s [%s]") % [
					art.get("icon", "✦"),
					tr(art.get("name", "")),
					tr(ArtifactData.get_slot_title(art.get("slot", "")))
				]
				btn.tooltip_text = tr("%s\n%s\n\n(Клик — надеть на героя)") % [tr(art.get("name", "")), tr(art.get("description", ""))]
				btn.custom_minimum_size = Vector2(0, 30)
				var target_art = a_id
				btn.pressed.connect(func():
					SoundManager.play_sfx("coin")
					GameState.equip_artifact(target_art)
					_update_hero_profile()
					_update_hud()
				)
				backpack_vbox.add_child(btn)

	# Secondary Skills
	for child in hero_skills_vbox.get_children():
		child.queue_free()
		
	var lvl_names = ["", "Базовый", "Продвинутый", "Эксперт"]
	for skill_id in GameState.skills.keys():
		var s_lvl: int = GameState.skills[skill_id]
		var s_data: Dictionary = GameState.ALL_SKILLS.get(skill_id, {})
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.22, 0.14, 0.06))
		var l_str = tr(lvl_names[clampi(s_lvl, 1, 3)])
		lbl.text = "%s %s (%s)\n%s" % [
			s_data.get("icon", "✦"),
			tr(s_data.get("name", skill_id)),
			l_str,
			tr(s_data.get("desc", ""))
		]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hero_skills_vbox.add_child(lbl)

func _process_next_level_up() -> void:
	if GameState.pending_level_ups.is_empty():
		level_dialog.hide()
		return
		
	var info: Dictionary = GameState.pending_level_ups[0]
	SoundManager.play_sfx("victory")
	level_sub_lbl.text = tr("Рыцарь Аларик достигает %d уровня!") % info["level"]
	level_stat_lbl.text = tr("✦ Основной атрибут: +1 к %s!") % info["stat"]
	
	var options: Array = info.get("options", [])
	var lvl_names = ["", "Базовый", "Продвинутый", "Эксперт"]
	
	# Setup Option 1
	if options.size() > 0:
		var opt1_id: String = options[0]
		var s1: Dictionary = GameState.ALL_SKILLS.get(opt1_id, {})
		var cur_l1: int = GameState.get_skill_level(opt1_id)
		var next_l1_name = lvl_names[clampi(cur_l1 + 1, 1, 3)]
		level_skill_btn1.text = tr("%s %s (%s уровень)\n%s") % [
			s1.get("icon", "✦"), tr(s1.get("name", opt1_id)), tr(next_l1_name), tr(s1.get("desc", ""))
		]
		level_skill_btn1.visible = true
		for c in level_skill_btn1.pressed.get_connections():
			level_skill_btn1.pressed.disconnect(c.callable)
		level_skill_btn1.pressed.connect(func():
			SoundManager.play_sfx("coin")
			GameState.learn_skill(opt1_id)
			GameState.pending_level_ups.remove_at(0)
			_process_next_level_up()
		)
	else:
		level_skill_btn1.visible = false
		
	# Setup Option 2
	if options.size() > 1:
		var opt2_id: String = options[1]
		var s2: Dictionary = GameState.ALL_SKILLS.get(opt2_id, {})
		var cur_l2: int = GameState.get_skill_level(opt2_id)
		var next_l2_name = lvl_names[clampi(cur_l2 + 1, 1, 3)]
		level_skill_btn2.text = tr("%s %s (%s уровень)\n%s") % [
			s2.get("icon", "✦"), tr(s2.get("name", opt2_id)), tr(next_l2_name), tr(s2.get("desc", ""))
		]
		level_skill_btn2.visible = true
		for c in level_skill_btn2.pressed.get_connections():
			level_skill_btn2.pressed.disconnect(c.callable)
		level_skill_btn2.pressed.connect(func():
			SoundManager.play_sfx("coin")
			GameState.learn_skill(opt2_id)
			GameState.pending_level_ups.remove_at(0)
			_process_next_level_up()
		)
	else:
		level_skill_btn2.visible = false
		
	SoundManager.play_sfx("level_up")
	level_dialog.move_to_front()
	level_dialog.show()

func _process(delta: float) -> void:
	if minimap_canvas and is_instance_valid(minimap_canvas):
		_minimap_redraw_accum += delta
		if _minimap_redraw_accum >= 0.1:
			_minimap_redraw_accum = 0.0
			minimap_canvas.queue_redraw()

func _setup_minimap_and_menu() -> void:
	# 1. Minimap Panel (Top-Right: width 224, height 204)
	minimap_container = Control.new()
	minimap_container.name = "MinimapPanel"
	minimap_container.anchors_preset = Control.PRESET_TOP_RIGHT
	minimap_container.anchor_left = 1.0
	minimap_container.anchor_right = 1.0
	minimap_container.offset_left = -240.0
	minimap_container.offset_top = 12.0
	minimap_container.offset_right = -16.0
	minimap_container.offset_bottom = 216.0
	$CanvasLayer.add_child(minimap_container)
	# Move to back so all popup dialogs render in front of it!
	$CanvasLayer.move_child(minimap_container, 0)

	var bg = NinePatchRect.new()
	bg.texture = load("res://assets/art/ui/parchment_panel.png")
	bg.patch_margin_left = 16
	bg.patch_margin_top = 16
	bg.patch_margin_right = 16
	bg.patch_margin_bottom = 16
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0
	minimap_container.add_child(bg)

	var title = Label.new()
	title.text = "МИНИ-КАРТА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	title.offset_left = 0
	title.offset_top = 6
	title.offset_right = 224
	title.offset_bottom = 26
	bg.add_child(title)

	# Minimap Drawing Canvas (32 cols * 5 = 160 px, 22 rows * 5 = 110 px)
	minimap_canvas = Control.new()
	minimap_canvas.name = "MinimapCanvas"
	minimap_canvas.custom_minimum_size = Vector2(160, 110)
	minimap_canvas.offset_left = 32
	minimap_canvas.offset_top = 28
	minimap_canvas.offset_right = 192
	minimap_canvas.offset_bottom = 138
	minimap_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	bg.add_child(minimap_canvas)

	minimap_canvas.draw.connect(_draw_minimap)
	minimap_canvas.gui_input.connect(_on_minimap_gui_input)

	# Bottom Buttons under minimap: Center, Zoom-, Zoom+, Menu
	var btn_hbox = HBoxContainer.new()
	btn_hbox.offset_left = 12
	btn_hbox.offset_top = 146
	btn_hbox.offset_right = 212
	btn_hbox.offset_bottom = 188
	btn_hbox.add_theme_constant_override("separation", 6)
	bg.add_child(btn_hbox)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.22, 0.13, 0.06, 0.92)
	btn_normal.border_color = Color(0.86, 0.68, 0.26, 0.95)
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)
	btn_normal.content_margin_left = 4.0
	btn_normal.content_margin_right = 4.0
	btn_normal.content_margin_top = 4.0
	btn_normal.content_margin_bottom = 4.0

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.36, 0.22, 0.1, 0.96)
	btn_hover.border_color = Color(1.0, 0.88, 0.45, 1.0)

	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.14, 0.08, 0.03, 0.98)
	btn_pressed.border_color = Color(0.7, 0.52, 0.18, 0.95)

	var center_btn = Button.new()
	center_btn.text = "🧭"
	center_btn.tooltip_text = "Центрировать камеру на герое"
	center_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		_center_camera_on_hero()
	)
	btn_hbox.add_child(center_btn)

	var zoom_out_btn = Button.new()
	zoom_out_btn.text = "🔍-"
	zoom_out_btn.tooltip_text = "Уменьшить масштаб"
	zoom_out_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_out_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		_set_map_zoom(map_zoom - 0.1)
	)
	btn_hbox.add_child(zoom_out_btn)

	var zoom_in_btn = Button.new()
	zoom_in_btn.text = "🔍+"
	zoom_in_btn.tooltip_text = "Увеличить масштаб"
	zoom_in_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_in_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		_set_map_zoom(map_zoom + 0.1)
	)
	btn_hbox.add_child(zoom_in_btn)

	var menu_btn = Button.new()
	menu_btn.text = "⚙️"
	menu_btn.tooltip_text = "Походный лагерь и настройки"
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.pressed.connect(func():
		SoundManager.play_sfx("page_turn")
		_toggle_pause_menu()
	)
	btn_hbox.add_child(menu_btn)

	for b in [center_btn, zoom_out_btn, zoom_in_btn, menu_btn]:
		b.add_theme_stylebox_override("normal", btn_normal)
		b.add_theme_stylebox_override("hover", btn_hover)
		b.add_theme_stylebox_override("pressed", btn_pressed)
		b.add_theme_stylebox_override("focus", btn_hover)
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 36)

	# Ensure QuestHUD is positioned cleanly below MinimapPanel with zero overlap
	var quest_hud = $CanvasLayer.get_node_or_null("QuestHUD")
	if quest_hud:
		quest_hud.offset_top = minimap_container.offset_bottom + 12.0
		quest_hud.offset_bottom = quest_hud.offset_top + 165.0
		quest_hud.offset_right = -16.0
		quest_hud.offset_left = -345.0

	# 2. Pause & Settings Dialog
	_setup_pause_dialog()

func _draw_minimap() -> void:
	if not is_instance_valid(world_view) or not minimap_canvas:
		return
	var cw = 160.0 / float(world_view.MAP_COLS)
	var ch = 110.0 / float(world_view.MAP_ROWS)

	# Dark background
	minimap_canvas.draw_rect(Rect2(0, 0, 160, 110), Color(0.1, 0.12, 0.08, 0.95))

	for y in range(world_view.MAP_ROWS):
		for x in range(world_view.MAP_COLS):
			var cell = Vector2i(x, y)
			if not world_view.revealed_cells.has(cell):
				continue
			var col = Color(0.28, 0.48, 0.22)
			if world_view.forest_cells.has(cell):
				col = Color(0.12, 0.32, 0.12)
			elif world_view.road_cells.has(cell):
				col = Color(0.55, 0.42, 0.25)
			minimap_canvas.draw_rect(Rect2(x * cw, y * ch, cw, ch), col)

	# Objects / Encounters
	for cell in world_view.objects.keys():
		if not world_view.revealed_cells.has(cell):
			continue
		var obj = world_view.objects[cell]
		var obj_t = obj.get("type", "")
		var o_col = Color(0.3, 0.8, 0.9)
		if obj_t in ["encounter", "bandit_boss", "crypt_guardian", "lich_citadel", "dragon_encounter"]:
			o_col = Color(0.95, 0.25, 0.25)
		elif obj_t == "chest":
			o_col = Color(1.0, 0.85, 0.2)
		minimap_canvas.draw_rect(Rect2(cell.x * cw + 1, cell.y * ch + 1, cw - 2, ch - 2), o_col)

	# Hero Position
	var h_pos = Vector2(world_view.hero_cell.x * cw + cw / 2.0, world_view.hero_cell.y * ch + ch / 2.0)
	minimap_canvas.draw_circle(h_pos, 3.5, Color(0.2, 1.0, 0.3))
	# Quest objective: pulsing golden marker
	var obj_cell = world_view.objective_cell
	if obj_cell.x >= 0:
		var o_pos = Vector2(obj_cell.x * cw + cw / 2.0, obj_cell.y * ch + ch / 2.0)
		var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
		minimap_canvas.draw_arc(o_pos, 4.0 + pulse * 3.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.2, 0.9), 1.6)
		minimap_canvas.draw_circle(o_pos, 2.0, Color(1.0, 0.85, 0.2, 0.95))


	# Camera Viewport Rect
	if is_instance_valid(scroll_container):
		var ts = float(world_view.TILE_SIZE)
		var vx = (float(scroll_container.scroll_horizontal) / ts) * cw
		var vy = (float(scroll_container.scroll_vertical) / ts) * ch
		var vw = (float(scroll_container.size.x) / ts) * cw
		var vh = (float(scroll_container.size.y) / ts) * ch
		minimap_canvas.draw_rect(Rect2(vx, vy, vw, vh), Color(1.0, 1.0, 1.0, 0.7), false, 1.0)

func _on_minimap_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cw = 160.0 / float(world_view.MAP_COLS)
		var ch = 110.0 / float(world_view.MAP_ROWS)
		var target_cell = Vector2i(int(event.position.x / cw), int(event.position.y / ch))
		var target_pos = Vector2(target_cell.x * world_view.TILE_SIZE, target_cell.y * world_view.TILE_SIZE)
		scroll_container.scroll_horizontal = int(max(0, target_pos.x - scroll_container.size.x / 2.0))
		scroll_container.scroll_vertical = int(max(0, target_pos.y - scroll_container.size.y / 2.0))
		minimap_canvas.queue_redraw()

func _setup_pause_dialog() -> void:
	pause_dialog = Control.new()
	pause_dialog.name = "PauseDialog"
	pause_dialog.visible = false
	pause_dialog.z_index = 60
	pause_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(pause_dialog)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	pause_dialog.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_dialog.add_child(center)

	var parch = NinePatchRect.new()
	parch.texture = load("res://assets/art/ui/parchment_panel.png")
	parch.patch_margin_left = 24
	parch.patch_margin_top = 24
	parch.patch_margin_right = 24
	parch.patch_margin_bottom = 24
	parch.custom_minimum_size = Vector2(540, 520)
	center.add_child(parch)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	parch.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "ПОХОДНЫЙ ЛАГЕРЬ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	var resume_btn = Button.new()
	resume_btn.text = "Продолжить поход"
	resume_btn.custom_minimum_size = Vector2(0, 42)
	resume_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		pause_dialog.hide()
	)
	vbox.add_child(resume_btn)

	var save_btn = Button.new()
	save_btn.text = "💾 Сохранить игру"
	save_btn.custom_minimum_size = Vector2(0, 42)
	save_btn.pressed.connect(func():
		if GameState.save_game():
			SoundManager.play_sfx("coin")
			save_btn.text = "✓ Игра сохранена!"
			await get_tree().create_timer(1.2).timeout
			if is_instance_valid(save_btn):
				save_btn.text = "💾 Сохранить игру"
	)
	vbox.add_child(save_btn)

	var load_btn = Button.new()
	load_btn.text = "📂 Загрузить игру"
	load_btn.custom_minimum_size = Vector2(0, 42)
	load_btn.pressed.connect(func():
		if GameState.load_game():
			SoundManager.play_sfx("page_turn")
			get_tree().reload_current_scene()
		else:
			load_btn.text = "Файл сохранения не найден"
	)
	vbox.add_child(load_btn)

	# Слоты сохранений (1-3): сохранить / загрузить
	var slots_lbl = Label.new()
	slots_lbl.text = tr("Слоты сохранений (1-3):")
	slots_lbl.add_theme_font_size_override("font_size", 15)
	slots_lbl.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
	vbox.add_child(slots_lbl)

	var save_row = HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	var load_row = HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 8)
	for i in range(1, 4):
		var slot_idx = i
		var slot_path = GameState.SAVE_SLOTS[i]

		var sb = Button.new()
		sb.text = tr("💾 Слот %d") % i
		sb.tooltip_text = tr("Сохранить игру в выбранный слот")
		sb.custom_minimum_size = Vector2(0, 40)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(func():
			if GameState.save_game(slot_path):
				SoundManager.play_sfx("coin")
				sb.text = tr("✓ %d") % slot_idx
			else:
				sb.text = tr("✗ %d") % slot_idx
		)
		save_row.add_child(sb)

		var lb = Button.new()
		lb.text = tr("📂 %d") % i
		lb.tooltip_text = tr("Загрузить игру из выбранного слота")
		lb.custom_minimum_size = Vector2(0, 40)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.pressed.connect(func():
			if GameState.load_game(slot_path):
				SoundManager.play_sfx("page_turn")
				get_tree().reload_current_scene()
		)
		load_row.add_child(lb)

	vbox.add_child(save_row)
	vbox.add_child(load_row)

	var chron_btn = Button.new()
	chron_btn.text = tr("📜 Летопись подвигов")
	chron_btn.custom_minimum_size = Vector2(0, 42)
	chron_btn.pressed.connect(func():
		SoundManager.play_sfx("page_turn")
		_show_chronicle_dialog()
	)
	vbox.add_child(chron_btn)

	# Audio Settings
	var vol_title = Label.new()
	vol_title.text = "Настройки звука:"
	vol_title.add_theme_font_size_override("font_size", 16)
	vol_title.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
	vbox.add_child(vol_title)

	# Master Volume
	var master_box = HBoxContainer.new()
	var master_lbl = Label.new()
	master_lbl.text = tr("Общая громкость:")
	master_lbl.custom_minimum_size = Vector2(80, 0)
	master_lbl.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
	var master_slider = HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	master_slider.value = SettingsManager.master_volume
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_slider.value_changed.connect(func(v: float):
		SettingsManager.master_volume = v
		SettingsManager.apply()
		SettingsManager.save_settings()
	)
	master_box.add_child(master_lbl)
	master_box.add_child(master_slider)
	vbox.add_child(master_box)

	# Music Volume
	var music_box = HBoxContainer.new()
	var music_lbl = Label.new()
	music_lbl.text = "Музыка:"
	music_lbl.custom_minimum_size = Vector2(80, 0)
	music_lbl.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
	var music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = SoundManager.music_volume
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(func(v: float): SoundManager.set_music_volume(v))
	music_box.add_child(music_lbl)
	music_box.add_child(music_slider)
	vbox.add_child(music_box)

	# SFX Volume
	var sfx_box = HBoxContainer.new()
	var sfx_lbl = Label.new()
	sfx_lbl.text = "Звуки:"
	sfx_lbl.custom_minimum_size = Vector2(80, 0)
	sfx_lbl.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = SoundManager.sfx_volume
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.value_changed.connect(func(v: float): SoundManager.set_sfx_volume(v))
	sfx_box.add_child(sfx_lbl)
	sfx_box.add_child(sfx_slider)
	vbox.add_child(sfx_box)

	# Music/SFX sliders also persist
	music_slider.value_changed.connect(func(_v: float): SettingsManager.save_settings())
	sfx_slider.value_changed.connect(func(_v: float): SettingsManager.save_settings())

	# Language
	var lang_box = HBoxContainer.new()
	var lang_lbl = Label.new()
	lang_lbl.text = tr("Язык:")
	lang_lbl.custom_minimum_size = Vector2(80, 0)
	lang_lbl.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
	var lang_opt = OptionButton.new()
	lang_opt.add_item("Русский", 0)
	lang_opt.add_item("English", 1)
	lang_opt.select(1 if SettingsManager.locale == "en" else 0)
	lang_opt.item_selected.connect(func(idx: int):
		SoundManager.play_sfx("click")
		SettingsManager.set_locale("en" if idx == 1 else "ru")
	)
	lang_box.add_child(lang_lbl)
	lang_box.add_child(lang_opt)
	lang_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(lang_box)

	# Упрощённые анимации
	var anim_chk := CheckButton.new()
	anim_chk.text = tr("Упрощённые анимации (для слабых устройств)")
	anim_chk.button_pressed = SettingsManager.reduced_animations
	anim_chk.add_theme_color_override("font_color", Color(0.3, 0.18, 0.08))
	anim_chk.toggled.connect(func(on: bool):
		SettingsManager.reduced_animations = on
		SettingsManager.save_settings()
	)
	vbox.add_child(anim_chk)

	var menu_btn = Button.new()
	menu_btn.text = "Выйти в главное меню"
	menu_btn.custom_minimum_size = Vector2(0, 42)
	menu_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		GameState.save_game()
		get_tree().change_scene_to_file("res://src/main.tscn")
	)
	vbox.add_child(menu_btn)

## Короткий совет дня (каждый 2-й день, если нет недельного события)
const DAY_TIPS: Array[String] = [
	"Стрелки бьют вдвое слабее, если враг подошёл вплотную — прикрывайте фей-лучниц!",
	"Грифоны отвечают на все удары без устали. Отправляйте их первыми в гущу боя!",
	"Заклинание героя действует один раз за раунд — но не тратит ход отряда!",
	"Слепой враг пропускает ход, пока не получит урон. Ослепляйте самых опасных!",
	"Золото из сундука можно обменять на опыт — иногда опыт ценнее казны.",
	"Древни регенерируют каждый раунд — затягивайте бой на их стороне невыгодно.",
	"Навык Лидерства даёт отрядам шанс на дополнительный ход. Прокачивайте!",
	"Драконье дыхание пробивает строй на 2 гекса — не выстраивайтесь в линию!"
]

func _show_day_tip() -> void:
	if GameState.day % 2 != 0:
		return
	if not GameState.last_astrologers_event.is_empty():
		return
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	popup_btn2.visible = false
	popup_title.text = tr("💡 Совет дня")
	popup_text.text = DAY_TIPS[randi() % DAY_TIPS.size()]
	popup_btn1.text = tr("Спасибо, буду знать!")
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

func _show_no_mp_hint() -> void:
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	popup_btn2.visible = false
	popup_title.text = tr("Марш прерван")
	popup_text.text = tr("Очки хода исчерпаны. Завершите день (клавиша E или кнопка \"Завершить день\"), чтобы выступить в новый путь!")
	popup_btn1.text = tr("Ясно")
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

func _show_chronicle_dialog() -> void:
	if chronicle_dialog != null:
		chronicle_dialog.queue_free()
	chronicle_dialog = Control.new()
	chronicle_dialog.visible = false
	chronicle_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(chronicle_dialog)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			chronicle_dialog.hide()
	)
	chronicle_dialog.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chronicle_dialog.add_child(center)

	var parch = NinePatchRect.new()
	parch.texture = load("res://assets/art/ui/parchment_panel.png")
	parch.patch_margin_left = 24
	parch.patch_margin_top = 24
	parch.patch_margin_right = 24
	parch.patch_margin_bottom = 24
	parch.custom_minimum_size = Vector2(640, 620)
	center.add_child(parch)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	parch.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = tr("📜 ЛЕТОПИСЬ ПОДВИГОВ")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	var unlocked_count = GameState.chronicle.size()
	var sub = Label.new()
	sub.text = tr("Открыто подвигов: %d из %d") % [unlocked_count, GameState.CHRONICLE_DEFS.size()]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.45, 0.3, 0.15))
	vbox.add_child(sub)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	vbox.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	for feat in GameState.CHRONICLE_DEFS:
		var unlocked = GameState.is_feat_unlocked(feat["id"])
		var row = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st = StyleBoxFlat.new()
		st.set_corner_radius_all(6)
		st.bg_color = Color(1.0, 0.93, 0.6, 0.35) if unlocked else Color(0, 0, 0, 0.05)
		row.add_theme_stylebox_override("panel", st)
		var lbl = Label.new()
		var mark = "✅ " if unlocked else "🔒 "
		var when = ""
		if unlocked and GameState.chronicle.get(feat["id"], {}).get("day", 0) > 0:
			when = " • " + tr("день %d") % int(GameState.chronicle[feat["id"]]["day"])
		lbl.text = mark + tr(str(feat["title"])) + " — " + tr(str(feat["desc"])) + when
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05) if unlocked else Color(0.45, 0.4, 0.35))
		row.add_child(lbl)
		list.add_child(row)

	var close_b = Button.new()
	close_b.text = tr("Закрыть")
	close_b.custom_minimum_size = Vector2(180, 46)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(func():
		SoundManager.play_sfx("click")
		chronicle_dialog.hide()
	)
	vbox.add_child(close_b)

	chronicle_dialog.move_to_front()
	chronicle_dialog.show()


## Бродячий торговец: появляется раз в неделю на открытой свободной клетке.
func _spawn_merchant() -> void:
	world_view.remove_object_by_id("wandering_merchant")
	var candidates: Array[Vector2i] = []
	for y in range(world_view.MAP_ROWS):
		for x in range(world_view.MAP_COLS):
			var c := Vector2i(x, y)
			if c == world_view.hero_cell or not world_view.is_passable(c):
				continue
			if world_view.objects.has(c) or not world_view.revealed_cells.has(c):
				continue
			candidates.append(c)
	if candidates.is_empty():
		return
	var cell: Vector2i = candidates[randi() % candidates.size()]
	world_view.objects[cell] = {"type": "merchant", "name": "Бродячий торговец", "id": "wandering_merchant"}
	GameState.merchant_cell = cell
	GameState.spawn_merchant_offers()
	world_view.queue_redraw()

## Дата-драйвен наём: попап жилища из data/dwellings.json.
func _open_dwelling_popup(obj_id: String) -> void:
	var reg: Dictionary = DwellingData.get_dwelling(obj_id)
	if reg.is_empty():
		return
	popup_title.text = tr(str(reg.get("popup_title", "")))
	var stock: int = int(GameState.dwelling_stock.get(str(reg.get("stock_key", "")), 0))
	var cost := int(reg.get("cost", 50))
	popup_btn2.visible = false
	if stock <= 0:
		popup_text.text = tr(str(reg.get("soldout", "")))
		popup_btn1.text = tr("Понятно")
		for conn in popup_btn1.pressed.get_connections():
			popup_btn1.pressed.disconnect(conn.callable)
		popup_btn1.pressed.connect(func(): popup_dialog.hide())
		_show_popup_dialog()
		return
	popup_text.text = tr(str(reg.get("intro", ""))) % [stock, cost, GameState.gold]
	var max_can_buy: int = mini(stock, GameState.gold / cost)
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	if max_can_buy <= 0:
		popup_btn1.text = tr("Недостаточно золота (нужно хотя бы %d зол.)") % cost
		popup_btn1.pressed.connect(func(): popup_dialog.hide())
	else:
		popup_btn1.text = tr(str(reg.get("hire_btn", ""))) % [max_can_buy, max_can_buy * cost]
		popup_btn1.pressed.connect(func():
			if not GameState.can_add_units(str(reg.get("unit", ""))):
				_show_army_full_popup()
				return
			if GameState.spend_gold(max_can_buy * cost):
				SoundManager.play_sfx("coin")
				GameState.dwelling_stock[str(reg.get("stock_key", ""))] -= max_can_buy
				GameState.add_units_to_army(str(reg.get("unit", "")), max_can_buy)
				GameState.flags[obj_id] = true
				world_view.queue_redraw()
				popup_dialog.hide()
		)
	_show_popup_dialog()

## Сказочная встреча (data/map_events.json): история и до двух вариантов выбора.
## Попап показывает _trigger_object.
func _open_map_event(ev_id: String) -> void:
	var ev := MapEventData.get_event(ev_id)
	popup_title.text = tr(str(ev.get("title", "")))
	popup_text.text = tr(str(ev.get("text", "")))
	var choices: Array = ev.get("choices", [])
	var btns := [popup_btn1, popup_btn2]
	for i in range(2):
		var btn: Button = btns[i]
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		btn.visible = i < choices.size()
		if i < choices.size():
			var choice: Dictionary = choices[i]
			btn.text = tr(str(choice.get("label", "")))
			btn.pressed.connect(func(): _resolve_map_event(ev_id, choice))
	if choices.is_empty():
		popup_btn1.visible = true
		popup_btn1.text = tr("Продолжить путь")
		popup_btn1.pressed.connect(func(): popup_dialog.hide())

## Выбор во встрече: эффекты, флаги, итог. Встреча исчезает, если у выбора нет keep.
func _resolve_map_event(ev_id: String, choice: Dictionary) -> void:
	var fx: Dictionary = choice.get("effects", {})
	var price := -int(fx.get("gold", 0))
	_reset_popup_buttons()
	popup_btn1.text = tr("Продолжить путь")
	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	if price > GameState.gold:
		SoundManager.play_sfx("click")
		popup_text.text = tr("Кажется, в кошельке не хватает золота.")
		_show_popup_dialog()
		return
	var lines := GameState.apply_event_effects(fx)
	if not choice.get("keep", false):
		GameState.flags[ev_id] = true
	if str(choice.get("set_flag", "")) != "":
		GameState.flags[str(choice["set_flag"])] = true
	world_view.place_map_events()
	world_view.queue_redraw()
	SoundManager.play_sfx("coin" if int(fx.get("gold", 0)) > 0 else ("spell_cast" if lines.size() > 0 else "page_turn"))
	popup_text.text = tr(str(choice.get("result", "")))
	if lines.size() > 0:
		popup_text.text += "\n\n" + "\n".join(lines)
	_update_hud()
	GameState.save_game()
	_show_popup_dialog()

## Кодекс существ: все юниты с характеристиками и способностями.
func _show_bestiary_dialog() -> void:
	var bd = Control.new()
	bd.visible = false
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(bd)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			bd.hide()
	)
	bd.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bd.add_child(center)

	var parch = NinePatchRect.new()
	parch.texture = load("res://assets/art/ui/parchment_panel.png")
	parch.patch_margin_left = 24
	parch.patch_margin_top = 24
	parch.patch_margin_right = 24
	parch.patch_margin_bottom = 24
	parch.custom_minimum_size = Vector2(700, 640)
	center.add_child(parch)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	parch.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = tr("📖 КОДЕКС СУЩЕСТВ")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 420)
	vbox.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var ids := UnitData.UNITS.keys()
	ids.sort_custom(func(a, b):
		var ua: Dictionary = UnitData.UNITS[a]
		var ub: Dictionary = UnitData.UNITS[b]
		if int(ua.get("tier", 0)) != int(ub.get("tier", 0)):
			return int(ua.get("tier", 0)) < int(ub.get("tier", 0))
		return str(ua.get("name", "")) < str(ub.get("name", ""))
	)
	for uid in ids:
		var u: Dictionary = UnitData.UNITS[uid]
		var row = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st = StyleBoxFlat.new()
		st.set_corner_radius_all(6)
		st.bg_color = Color(1.0, 0.93, 0.6, 0.18)
		row.add_theme_stylebox_override("panel", st)
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		var token = TextureRect.new()
		token.custom_minimum_size = Vector2(56, 56)
		token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tpath = u.get("token_path", "")
		if ResourceLoader.exists(tpath):
			token.texture = load(tpath)
		hb.add_child(token)
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hb.add_child(info)
		var name_l = Label.new()
		name_l.text = "%s — %s %d" % [tr(str(u.get("name", uid))), tr("тир"), int(u.get("tier", 1))]
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.add_theme_color_override("font_color", Color(0.6, 0.42, 0.1))
		info.add_child(name_l)
		var stats_l = Label.new()
		stats_l.text = "❤ %d   ⚔ %d-%d   🛡 %d   💨 %d   ✦ %d" % [
			int(u.get("max_hp", 0)), int(u.get("min_dmg", 0)), int(u.get("max_dmg", 0)),
			int(u.get("defense", 0)), int(u.get("speed", 0)), int(u.get("initiative", 0))
		]
		stats_l.add_theme_font_size_override("font_size", 13)
		stats_l.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05))
		info.add_child(stats_l)
		var traits_l = Label.new()
		traits_l.text = tr(UnitData.get_trait_string(uid))
		traits_l.add_theme_font_size_override("font_size", 12)
		traits_l.add_theme_color_override("font_color", Color(0.45, 0.32, 0.12))
		info.add_child(traits_l)
		var desc_l = Label.new()
		desc_l.text = tr(str(u.get("description", "")))
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.add_theme_font_size_override("font_size", 12)
		desc_l.add_theme_color_override("font_color", Color(0.3, 0.22, 0.12))
		info.add_child(desc_l)
		list.add_child(row)

	var close_b = Button.new()
	close_b.text = tr("Закрыть")
	close_b.custom_minimum_size = Vector2(180, 46)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(func():
		SoundManager.play_sfx("click")
		bd.hide()
	)
	vbox.add_child(close_b)

	bd.move_to_front()
	bd.show()

func _toggle_pause_menu() -> void:
	if pause_dialog:
		if not pause_dialog.visible:
			pause_dialog.move_to_front()
			pause_dialog.show()
		else:
			pause_dialog.hide()

func _show_chapter_intro() -> void:
	for conn in popup_btn1.pressed.get_connections():
		popup_btn1.pressed.disconnect(conn.callable)
	for conn in popup_btn2.pressed.get_connections():
		popup_btn2.pressed.disconnect(conn.callable)
	popup_btn2.visible = false

	match GameState.current_chapter:
		2:
			popup_title.text = "★ ГЛАВА 2: ПРОКЛЯТЫЕ ТОПИ ★"
			popup_text.text = "Ваше победоносное войско вступило в туманные трясины Топей Скорби!\n\nДревний Лич осквернил святилища и поднял из болотных могил орды скелетов и зомби. Трясина бурлит темной скверной!\n\n✦ ВАШИ ЦЕЛИ В ГЛАВЕ 2:\n1. Отыщите Хижину Болотной Ведьмы (6, 17) и добудьте Костяной Ключ.\n2. Преодолейте трясину и откройте Костяные Врата (14, 11).\n3. Сокрушите Древнего Лича в Цитадели (28, 11) и очистите Алтарь Друидов (27, 4)!"
			popup_btn1.text = "⚔ Очистить Топи от скверны!"
		3:
			popup_title.text = "★ ГЛАВА 3: ПИК ДРАКОНА ★"
			popup_text.text = "Перед вами вздымаются багровые скалы Огненного Пика!\n\nКрасный Дракон пробудился и сжигает горные перевалы. Это решающая битва за спасение всего Королевства!\n\n✦ ВАШИ ЦЕЛИ В ГЛАВЕ 3:\n1. Скуйте легендарную броню в Кузнице Владык (10, 4).\n2. Преодолейте Огненные Врата Ущелья (14, 11).\n3. Сокрушите Красного Дракона на вершине Пика (28, 11) и прибудьте в Цитадель (27, 4)!"
			popup_btn1.text = "👑 К Великой Победе!"
		_:
			popup_title.text = "★ ГЛАВА 1: ЗАЧАРОВАННЫЙ ЛЕС ★"
			popup_text.text = "Добро пожаловать в земли Сказочного Леса!\n\nШайки разбойников атаковали Священную Рощу и похитили священный Венец Королевы Фей. Без него древняя магия леса увядает.\n\n✦ ВАШИ ЦЕЛИ В ГЛАВЕ 1:\n1. Очистите долину от банд гоблинов и стай волков.\n2. Навестите Хижину Лесника (7, 18) на юге за Ключом от Врат.\n3. Сразите Атамана в Логове (28, 11) и верните Венец Королеве Фей (27, 4)!"
			popup_btn1.text = "Выступить в поход!"

	popup_btn1.pressed.connect(func(): popup_dialog.hide())
	_show_popup_dialog()

func _get_encounter_desc(obj_id: String, en_name: String) -> String:
	match obj_id:
		"patrol_wolves":
			return "Стая свирепых серых волков окружила подходы к старой мельнице!\nРазведка доносит: [Стая (16 волков)].\nОни жаждут крови и не пропустят вас к мукомольне!"
		"patrol_goblins":
			return "Шайка лесных гоблинов-грабителей делит золото возле сундука!\nРазведка доносит: [Орда (24 гоблина, 6 волков)].\nОни бросают награбленное и хватаются за топоры!"
		"patrol_forester":
			return "Из густых зарослей у южного тракта свистят стрелы разбойничьей засады!\nРазведка доносит: [Отряд (18 гоблинов, 8 волков)].\nБандиты перекрыли дорогу к хижине лесника!"
		"patrol_grove":
			return "Древний Древень пробудился от векового сна и преграждает путь к тайнику в чащобе!\nРазведка доносит: [Стражи (3 древня, 10 волков)].\nЛес защищает свои древние секреты!"
		"patrol_1":
			return "Из-за скал перевала выступает тяжелый авангард разбойников!\nРазведка доносит: [Орда (25 гоблинов, 12 волков)].\nОни охраняют восточную долину атамана!"
		"patrol_rogues":
			return "Отряд опытных бандитских стрелков устроил заслон на северной тропе!\nРазведка доносит: [Орда (26 гоблинов, 14 волков)].\nОни блокируют подходы к Священной Роще Фей!"
		"patrol_obelisk":
			return "Элитная личная гвардия Атамана охраняет Древний Обелиск и сокровищницу!\nРазведка доносит: [Орда (3 древня, 20 гоблинов, 10 волков)]."
		"swamp_patrol_road":
			return "Зловонный трупный запах возвещает о приближении болотных зомби!\nРазведка доносит: [Орда (18 болотных зомби)].\nОни бредут прямо по настилу гати!"
		"swamp_patrol_fens":
			return "Скелеты-лучники поднимают костяные луки среди болотного мха!\nРазведка доносит: [Орда (20 скелетов-лучников)].\nОни перекрыли тропу к Хижине Ведьмы!"
		"swamp_patrol_gate":
			return "Костяная гвардия Некрополя заступила дорогу перед Костяными Вратами!\nРазведка доносит: [Орда (22 скелета-лучника, 14 зомби)]."
		"swamp_patrol_east":
			return "Легион Тьмы патрулирует дорогу к Алтарю Друидов!\nРазведка доносит: [Орда (24 скелета-лучника, 18 зомби)]."
		"swamp_patrol_ruins":
			return "Жуткие личи и скелеты охраняют проклятые сокровища древнего склепа!\nРазведка доносит: [Тьма (4 лича, 20 скелетов, 12 зомби)]."
		"dragon_patrol_pass":
			return "Огненный дозор ущелья преграждает путь по горной тропе!\nРазведка доносит: [Орда (24 гоблина, 16 волков)]."
		"dragon_patrol_gate":
			return "Стража Огненных Врат охраняет вход в цитадель перевала!\nРазведка доносит: [Орда (22 скелета, 25 гоблинов, 14 волков)]."
		"dragon_patrol_caldera":
			return "Слуги дракона не подпускают никого к жерлу вулкана!\nРазведка доносит: [Орда (25 гоблинов, 16 волков, 4 древня)]."
		"dragon_patrol_citadel":
			return "Лавовые хищники кружат над плато у Королевской Цитадели!\nРазведка доносит: [Стая (12 грифонов, 22 гоблина)]."
		_:
			return tr("Вражеский отряд преграждает путь (%s)!\nРазведка оценивает силы противника: [Орда (20-40 бойцов)].\nОни готовы вступить в схватку!") % en_name
