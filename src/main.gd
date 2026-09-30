class_name MainMenu
extends Control

const UnitData = preload("res://src/core/unit_data.gd")

var modal_layer: CanvasLayer
var chapter_dialog: Control
var hero_select_dialog: Control
var music_dialog: Control
var arena_dialog: Control
var about_dialog: Control

var current_theme_idx: int = 0
var mini_player_btn: Button

const MENU_THEMES: Array[Dictionary] = [
	# --- HoMM 2 Style Baroque Harpsichord Themes (1 - 20) ---
	{"file": "res://assets/audio/music/themes/homm2_01_sorceress_garden.ogg", "name": "01. Сад Волшебницы (HoMM2)", "mood": "Виртуозный клавесин, пасторальная флейта, хрустальные колокольчики"},
	{"file": "res://assets/audio/music/themes/homm2_02_knight_castle.ogg", "name": "02. Замок Рыцаря (HoMM2)", "mood": "Благородный контрапункт на клавесине, лютня и королевские фанфары"},
	{"file": "res://assets/audio/music/themes/homm2_03_warlock_dungeon.ogg", "name": "03. Башня Чернокнижника (HoMM2)", "mood": "Нисходящие минорные пассажи клавесина, пиццикато и полночный перезвон"},
	{"file": "res://assets/audio/music/themes/homm2_04_wizard_academy.ogg", "name": "04. Академия Магов (HoMM2)", "mood": "Барочная пассакалья 3/4 на клавесине и волшебная челеста"},
	{"file": "res://assets/audio/music/themes/homm2_05_baroque_gavotte.ogg", "name": "05. Придворный Гавот (HoMM2)", "mood": "Игривый стаккато-танец клавесина и флейтовый дуэт"},
	{"file": "res://assets/audio/music/themes/homm2_06_fairytale_minuet.ogg", "name": "06. Сказочный Менуэт (HoMM2)", "mood": "Изящный 3/4 менуэт с мордентами клавесина и щипковой лютней"},
	{"file": "res://assets/audio/music/themes/homm2_07_enchanted_fountain.ogg", "name": "07. Зачарованный Фонтан (HoMM2)", "mood": "Искрящиеся шестнадцатые переборы клавесина, словно струи воды"},
	{"file": "res://assets/audio/music/themes/homm2_08_harpsichord_invention.ogg", "name": "08. Двухголосная Инвенция (HoMM2)", "mood": "Классический баховский полифонический диалог двух голосов"},
	{"file": "res://assets/audio/music/themes/homm2_09_court_jester_gigue.ogg", "name": "09. Шут при Дворе — Жига (HoMM2)", "mood": "Задорный галоп 6/8, прыгающий клавесин и средневековая лютня"},
	{"file": "res://assets/audio/music/themes/homm2_10_princess_pavane.ogg", "name": "10. Павана Принцессы (HoMM2)", "mood": "Величавая ренессансная поступь, нежный клавесин и басовая лютня"},
	{"file": "res://assets/audio/music/themes/homm2_11_alchemist_laboratory.ogg", "name": "11. Лаборатория Алхимика (HoMM2)", "mood": "Хроматические барочные фигуры, стеклянные колокольчики и орган"},
	{"file": "res://assets/audio/music/themes/homm2_12_druid_grove.ogg", "name": "12. Священная Роща Друидов (HoMM2)", "mood": "Дорийский напев лесной флейты над струящимися аккордами клавесина"},
	{"file": "res://assets/audio/music/themes/homm2_13_troubadour_serenade.ogg", "name": "13. Серенада Трубадура (HoMM2)", "mood": "Романтичный клавесин и мягкая щипковая виуэла менестреля"},
	{"file": "res://assets/audio/music/themes/homm2_14_magic_music_box.ogg", "name": "14. Волшебная Шкатулка (HoMM2)", "mood": "Звонкий высокий спинет и сказочные колокольчики фей"},
	{"file": "res://assets/audio/music/themes/homm2_15_royal_cembalo_march.ogg", "name": "15. Королевский Чембало-Марш (HoMM2)", "mood": "Пышные арпеджированные аккорды клавесина и праздничный шаг"},
	{"file": "res://assets/audio/music/themes/homm2_16_pastoral_dawn.ogg", "name": "16. Пасторальный Рассвет (HoMM2)", "mood": "Пробуждение лесной чащи, птичьи трели флейты и рассветный клавесин"},
	{"file": "res://assets/audio/music/themes/homm2_17_clavier_fughetta.ogg", "name": "17. Клавирная Фугетта (HoMM2)", "mood": "Строгий старинный контрапункт с проведением темы во всех голосах"},
	{"file": "res://assets/audio/music/themes/homm2_18_crystal_spinet.ogg", "name": "18. Хрустальный Спинет (HoMM2)", "mood": "Виртуозная токката в духе Скарлатти с быстрыми репетициями нот"},
	{"file": "res://assets/audio/music/themes/homm2_19_archers_pavilion.ogg", "name": "19. Шатёр Лесных Лучников (HoMM2)", "mood": "Ритмичный стаккато-клавесин и удалой мотив стрелков Шервуда"},
	{"file": "res://assets/audio/music/themes/homm2_20_archmage_fantasia.ogg", "name": "20. Фантазия Верховного Мага (HoMM2)", "mood": "Драматическая барочная кульминация с органом и мажорным разрешением"},

	# --- Symphonic & Fantasy Themes (21 - 40) ---
	{"file": "res://assets/audio/music/themes/theme_01_fairy_forest.ogg", "name": "21. Зачарованный Лес", "mood": "Сказочные флейты, арфа и мягкий ветер"},
	{"file": "res://assets/audio/music/themes/theme_02_royal_march.ogg", "name": "22. Королевский Марш", "mood": "Торжественные медные духовые и барабаны"},
	{"file": "res://assets/audio/music/themes/theme_03_cozy_tavern.ogg", "name": "23. Уютная Таверна", "mood": "Веселый средневековый танец, лютня"},
	{"file": "res://assets/audio/music/themes/theme_04_mystic_sanctuary.ogg", "name": "24. Тайное Святилище", "mood": "Мистический эмбиент-пад и колокольчики"},
	{"file": "res://assets/audio/music/themes/theme_05_wanderer_ballad.ogg", "name": "25. Баллада Странника", "mood": "Ностальгическая свирель и переборы струн"},
	{"file": "res://assets/audio/music/themes/theme_06_knights_honor.ogg", "name": "26. Рыцарская Честь", "mood": "Благородные валторны и струнные"},
	{"file": "res://assets/audio/music/themes/theme_07_crystal_spring.ogg", "name": "27. Хрустальный Источник", "mood": "Серебряные переливы челесты и ручей"},
	{"file": "res://assets/audio/music/themes/theme_08_homm_nostalgia.ogg", "name": "28. Ностальгия Героев", "mood": "Классический клавесин в духе HoMM3"},
	{"file": "res://assets/audio/music/themes/theme_09_ancient_ruins.ogg", "name": "29. Древние Руины", "mood": "Загадочный хор предков и глубокий гонг"},
	{"file": "res://assets/audio/music/themes/theme_10_morning_meadow.ogg", "name": "30. Утренний Луг", "mood": "Пасторальная дудочка и птичьи трели"},
	{"file": "res://assets/audio/music/themes/theme_11_celtic_dance.ogg", "name": "31. Кельтский Праздник", "mood": "Бодрая кельтская джига и волынка"},
	{"file": "res://assets/audio/music/themes/theme_12_foggy_swamp.ogg", "name": "32. Туманные Топи", "mood": "Таинственный низкий гул и капли"},
	{"file": "res://assets/audio/music/themes/theme_13_glory_triumph.ogg", "name": "33. Триумф Королевства", "mood": "Победные фанфары и литавры"},
	{"file": "res://assets/audio/music/themes/theme_14_moonlight_grove.ogg", "name": "34. Лунная Роща", "mood": "Мерцающие колокольчики и фортепиано"},
	{"file": "res://assets/audio/music/themes/theme_15_battle_call.ogg", "name": "35. Зов Битвы", "mood": "Энергичный ритм и боевой марш"},
	{"file": "res://assets/audio/music/themes/theme_16_fairy_lullaby.ogg", "name": "36. Колыбельная Фей", "mood": "Нежная музыкальная шкатулка"},
	{"file": "res://assets/audio/music/themes/theme_17_dragon_peak.ogg", "name": "37. Пик Дракона", "mood": "Величественные медные и размах гор"},
	{"file": "res://assets/audio/music/themes/theme_18_minstrel_song.ogg", "name": "38. Песнь Менестреля", "mood": "Старинная баллада бродячего барда (плавный бесшовный луп)"},
	{"file": "res://assets/audio/music/themes/theme_19_cathedral_light.ogg", "name": "39. Храм Света", "mood": "Священный орган и светлые гармонии"},
	{"file": "res://assets/audio/music/themes/theme_20_epic_fairytale.ogg", "name": "40. Великая Сказка", "mood": "Полнозвучная симфоническая увертюра"}
]

func _ready() -> void:
	# Dedicated top layer for all popup modals
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 100
	add_child(modal_layer)

	# --- Primary Action Cards ---
	var continue_btn: Button = $SafeMargin/MainVBox/CenterSection/ActionCards/ContinueBtn
	if GameState.has_save_game(GameState.get_newest_save_path()):
		continue_btn.visible = true
		var summary = GameState.get_save_summary(GameState.get_newest_save_path())
		if summary.size() > 0:
			var h_name = summary.get("hero_name", "Герой")
			var chap = summary.get("chapter", 1)
			var d = summary.get("day", 1)
			var lvl = summary.get("level", 1)
			continue_btn.text = tr("📜 Продолжить поход  [%s • Гл. %d, День %d • Ур. %d]") % [tr(h_name), chap, d, lvl]
		else:
			continue_btn.text = "📜 Продолжить поход"
		continue_btn.pressed.connect(_on_continue_adventure)
	else:
		continue_btn.visible = false

	var start_btn: Button = $SafeMargin/MainVBox/CenterSection/ActionCards/StartAdventureBtn
	start_btn.pressed.connect(_on_start_adventure)

	var arena_btn: Button = $SafeMargin/MainVBox/CenterSection/ActionCards/ArenaBattleBtn
	arena_btn.pressed.connect(_on_arena_battle)

	var chap_btn: Button = $SafeMargin/MainVBox/CenterSection/ActionCards/ChapterSelectBtn
	chap_btn.pressed.connect(_open_chapter_dialog)

	# --- Bottom Toolbar ---
	var music_btn: Button = $SafeMargin/MainVBox/BottomToolbar/MusicSelectBtn
	music_btn.pressed.connect(_open_music_dialog)

	var about_btn: Button = $SafeMargin/MainVBox/BottomToolbar/AboutBtn
	about_btn.pressed.connect(_on_about)

	var settings_btn: Button = Button.new()
	settings_btn.text = tr("⚙️ Настройки")
	settings_btn.custom_minimum_size = Vector2(0, 50)
	$SafeMargin/MainVBox/BottomToolbar.add_child(settings_btn)
	settings_btn.pressed.connect(_open_settings_dialog)

	var chron_btn: Button = Button.new()
	chron_btn.text = tr("📜 Летопись подвигов")
	chron_btn.custom_minimum_size = Vector2(0, 50)
	$SafeMargin/MainVBox/BottomToolbar.add_child(chron_btn)
	chron_btn.pressed.connect(_open_chronicle_dialog)

	var best_btn: Button = Button.new()
	best_btn.text = tr("📖 Кодекс существ")
	best_btn.custom_minimum_size = Vector2(0, 50)
	$SafeMargin/MainVBox/BottomToolbar.add_child(best_btn)
	best_btn.pressed.connect(_open_bestiary_dialog)

	var exit_btn: Button = $SafeMargin/MainVBox/BottomToolbar/ExitBtn
	exit_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		get_tree().quit()
	)

	# --- Top Mini Music Player ---
	var prev_btn: Button = $SafeMargin/MainVBox/TopBar/RightBox/MiniMusicPlayer/PlayerHBox/PrevBtn
	var next_btn: Button = $SafeMargin/MainVBox/TopBar/RightBox/MiniMusicPlayer/PlayerHBox/NextBtn
	mini_player_btn = $SafeMargin/MainVBox/TopBar/RightBox/MiniMusicPlayer/PlayerHBox/TrackBtn

	prev_btn.pressed.connect(func():
		var next_idx = (current_theme_idx - 1 + MENU_THEMES.size()) % MENU_THEMES.size()
		_play_theme_by_index(next_idx)
	)
	next_btn.pressed.connect(func():
		var next_idx = (current_theme_idx + 1) % MENU_THEMES.size()
		_play_theme_by_index(next_idx)
	)
	mini_player_btn.pressed.connect(func():
		_open_music_dialog()
	)

	# Setup modals with rock-solid Centering
	_setup_chapter_selection_ui()
	_setup_hero_select_ui()
	_setup_music_selection_ui()
	_setup_arena_dialog_ui()
	_setup_about_dialog_ui()

	# Check saved music preference & initialize audio
	var pref = SoundManager.load_music_preference()
	if pref != "":
		for i in range(MENU_THEMES.size()):
			if MENU_THEMES[i]["file"] == pref:
				current_theme_idx = i
				break
	
	_update_mini_player_text()

	var theme_to_play = pref if pref != "" else MENU_THEMES[current_theme_idx]["file"]
	if SoundManager.current_music_path != theme_to_play or not SoundManager.music_player.playing:
		SoundManager.play_music(theme_to_play)

func _update_mini_player_text() -> void:
	if mini_player_btn != null and current_theme_idx >= 0 and current_theme_idx < MENU_THEMES.size():
		mini_player_btn.text = "🎵 %s" % tr(MENU_THEMES[current_theme_idx]["name"])

func _on_continue_adventure() -> void:
	SoundManager.play_sfx("click")
	if GameState.load_game(GameState.get_newest_save_path()):
		get_tree().change_scene_to_file("res://src/world/world_map.tscn")
	else:
		_on_start_adventure()

func _create_modal_dialog(dialog_name: String, panel_size: Vector2) -> Dictionary:
	var root = Control.new()
	root.name = dialog_name
	root.visible = false
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(root)

	# Dark screen backdrop with full touch & mouse support
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			root.hide()
	)
	root.add_child(backdrop)

	# CenterContainer mathematically centers child regardless of screen resolution
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(center)

	# Parchment panel
	var parch = NinePatchRect.new()
	parch.texture = load("res://assets/art/ui/parchment_panel.png")
	parch.patch_margin_left = 24
	parch.patch_margin_top = 24
	parch.patch_margin_right = 24
	parch.patch_margin_bottom = 24
	parch.custom_minimum_size = panel_size
	center.add_child(parch)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	parch.add_child(margin)

	return {
		"root": root,
		"backdrop": backdrop,
		"parch": parch,
		"margin": margin
	}

# 1. Chapter Selection UI
func _setup_chapter_selection_ui() -> void:
	var m = _create_modal_dialog("ChapterSelectDialog", Vector2(800, 530))
	chapter_dialog = m["root"]

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m["margin"].add_child(vbox)

	var title = Label.new()
	title.text = "СЮЖЕТНАЯ КАМПАНИЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Выберите главу для начала сказочного похода:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.45, 0.3, 0.15))
	vbox.add_child(sub)

	vbox.add_spacer(false)

	# Campaign difficulty selector
	var diff_lbl = Label.new()
	diff_lbl.text = tr("Сложность кампании:")
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.add_theme_font_size_override("font_size", 15)
	diff_lbl.add_theme_color_override("font_color", Color(0.45, 0.3, 0.15))
	vbox.add_child(diff_lbl)

	var diff_row = HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 8)
	vbox.add_child(diff_row)

	var chapter_diff = {"v": "normal"}
	var diff_btns: Array[Button] = []
	for diff_id in ["easy", "normal", "hard", "legendary"]:
		var ddata := GameState.get_difficulty_multipliers(diff_id)
		var d_btn := Button.new()
		d_btn.text = str(ddata["title"])
		d_btn.custom_minimum_size = Vector2(0, 40)
		d_btn.add_theme_font_size_override("font_size", 13)
		var dfortune := GameState.get_enemy_fortune(diff_id)
		if float(dfortune["luck"]) > 0.0:
			d_btn.tooltip_text = tr("Враг тоже ловит удачу (%d%%) и боевой дух (%d%%)") % [
				int(round(float(dfortune["luck"]) * 100.0)), int(round(float(dfortune["morale"]) * 100.0))
			]
		var did: String = diff_id
		d_btn.pressed.connect(func():
			SoundManager.play_sfx("click")
			chapter_diff["v"] = did
			for b in diff_btns:
				b.modulate = Color(0.75, 0.75, 0.75)
			d_btn.modulate = Color(1.0, 0.95, 0.6)
		)
		if diff_id == "normal":
			d_btn.modulate = Color(1.0, 0.95, 0.6)
		else:
			d_btn.modulate = Color(0.75, 0.75, 0.75)
		diff_row.add_child(d_btn)
		diff_btns.append(d_btn)

	# Chapter 1
	var c1_btn = Button.new()
	c1_btn.text = "🌲 Глава 1: Похищенный Венец (Зачарованный Лес)"
	c1_btn.custom_minimum_size = Vector2(0, 60)
	c1_btn.add_theme_font_size_override("font_size", 19)
	c1_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		GameState.reset()
		GameState.campaign_difficulty = chapter_diff["v"]
		GameState.start_chapter(1)
		get_tree().change_scene_to_file("res://src/world/world_map.tscn")
	)
	vbox.add_child(c1_btn)

	# Chapter 2
	var c2_btn = Button.new()
	c2_btn.text = "💀 Глава 2: Проклятые Топи (Древний Лич и Склепы)"
	c2_btn.custom_minimum_size = Vector2(0, 60)
	c2_btn.add_theme_font_size_override("font_size", 19)
	c2_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		GameState.reset()
		GameState.campaign_difficulty = chapter_diff["v"]
		GameState.level = 3
		GameState.next_level_xp = int(1000 * pow(1.5, 2))
		GameState.attack = 6
		GameState.defense = 5
		GameState.player_army = [
			{"unit_id": "griffin", "count": 10},
			{"unit_id": "royal_fairy", "count": 26}
		]
		GameState.start_chapter(2)
		get_tree().change_scene_to_file("res://src/world/world_map.tscn")
	)
	vbox.add_child(c2_btn)

	# Chapter 3
	var c3_btn = Button.new()
	c3_btn.text = "🔥 Глава 3: Пик Дракона (Огненный Владыка)"
	c3_btn.custom_minimum_size = Vector2(0, 60)
	c3_btn.add_theme_font_size_override("font_size", 19)
	c3_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		GameState.reset()
		GameState.campaign_difficulty = chapter_diff["v"]
		GameState.level = 5
		GameState.next_level_xp = int(1000 * pow(1.5, 4))
		GameState.attack = 8
		GameState.defense = 7
		GameState.player_army = [
			{"unit_id": "royal_griffin", "count": 12},
			{"unit_id": "royal_fairy", "count": 32},
			{"unit_id": "druid", "count": 10}
		]
		GameState.start_chapter(3)
		get_tree().change_scene_to_file("res://src/world/world_map.tscn")
	)
	vbox.add_child(c3_btn)

	vbox.add_spacer(false)

	var close_btn = Button.new()
	close_btn.text = "Назад"
	close_btn.custom_minimum_size = Vector2(180, 52)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		chapter_dialog.hide()
	)
	vbox.add_child(close_btn)

func _open_chapter_dialog() -> void:
	SoundManager.play_sfx("page_turn")
	chapter_dialog.show()

# 2. Hero Selection UI
func _setup_hero_select_ui() -> void:
	var m = _create_modal_dialog("HeroSelectDialog", Vector2(1040, 640))
	hero_select_dialog = m["root"]

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	m["margin"].add_child(main_vbox)

	var title = Label.new()
	title.text = "ВЫБЕРИТЕ КЛАСС ГЕРОЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	main_vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Определите путь и специализацию вашего полководца:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.45, 0.3, 0.15))
	main_vbox.add_child(sub)

	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 18)
	main_vbox.add_child(hbox)

	var classes_info = [
		{
			"id": "paladin",
			"icon": "⚔️",
			"name": "Рыцарь Аларик",
			"title": "Паладин Королевства",
			"portrait": "res://assets/art/portraits/hero_alaric.jpg",
			"desc": "Сбалансированный воин.\n\n• Атака: 4  |  Защита: 3\n• Магия: 3  |  Знание: 4\n• Навык: Лидерство (+30% крит)\n• Войско: 6 Грифонов, 18 Фей\n• Предмет: Меч Доблести (+4 Атк)"
		},
		{
			"id": "archmage",
			"icon": "✨",
			"name": "Чародейка Элеонора",
			"title": "Верховный Архимаг",
			"portrait": "res://assets/art/portraits/hero_archmage.jpg",
			"desc": "Мастер тайной магии.\n\n• Атака: 2  |  Защита: 2\n• Магия: 6  |  Знание: 6 (80 MP)\n• Навык: Волшебство (+25% урон чар)\n• Войско: 4 Грифона, 24 Феи\n• Предмет: Перстень Архимага"
		},
		{
			"id": "ranger",
			"icon": "🏹",
			"name": "Следопыт Торн",
			"title": "Хранитель Чащобы",
			"portrait": "res://assets/art/portraits/hero_ranger.jpg",
			"desc": "Быстрый разведчик лесов.\n\n• Атака: 3  |  Защита: 3\n• Магия: 2  |  Ход: 48 очков\n• Навык: Логистика, Поиск пути\n• Войско: 8 Грифонов, 14 Фей\n• Предмет: Сапоги Странника (+8 MP)"
		}
	]

	for cls in classes_info:
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.add_child(card)

		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 8)
		card.add_child(card_vbox)

		# Portrait Header
		var port_center = CenterContainer.new()
		port_center.custom_minimum_size = Vector2(0, 84)
		var port_rect = TextureRect.new()
		port_rect.custom_minimum_size = Vector2(76, 76)
		port_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		port_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var p_path = cls.get("portrait", "")
		if ResourceLoader.exists(p_path):
			port_rect.texture = load(p_path)
		port_center.add_child(port_rect)
		card_vbox.add_child(port_center)

		var hdr = Label.new()
		hdr.text = "%s %s" % [cls["icon"], tr(cls["name"])]
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_size_override("font_size", 18)
		hdr.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		card_vbox.add_child(hdr)

		var stitle = Label.new()
		stitle.text = cls["title"]
		stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stitle.add_theme_font_size_override("font_size", 13)
		stitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		card_vbox.add_child(stitle)

		var dlbl = Label.new()
		dlbl.text = cls["desc"]
		dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dlbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dlbl.add_theme_font_size_override("font_size", 13)
		card_vbox.add_child(dlbl)

		var pick_btn = Button.new()
		pick_btn.text = tr("Выбрать: %s") % tr(cls["name"]).split(" ")[0]
		pick_btn.custom_minimum_size = Vector2(0, 52)
		pick_btn.add_theme_font_size_override("font_size", 16)
		var cid = cls["id"]
		pick_btn.pressed.connect(func():
			SoundManager.play_sfx("victory")
			GameState.reset()
			GameState.set_hero_class(cid)
			GameState.start_chapter(1)
			get_tree().change_scene_to_file("res://src/world/world_map.tscn")
		)
		card_vbox.add_child(pick_btn)

	var close_btn = Button.new()
	close_btn.text = "Отмена"
	close_btn.custom_minimum_size = Vector2(180, 52)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		hero_select_dialog.hide()
	)
	main_vbox.add_child(close_btn)

func _on_start_adventure() -> void:
	SoundManager.play_sfx("page_turn")
	hero_select_dialog.show()

# 3. 40-Themes Music Jukebox UI
func _setup_music_selection_ui() -> void:
	var m = _create_modal_dialog("MusicSelectDialog", Vector2(960, 640))
	music_dialog = m["root"]

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	m["margin"].add_child(vbox)

	var title = Label.new()
	title.text = "🎼 МУЗЫКАЛЬНАЯ ШКАТУЛКА (40 ТЕМ)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "20 тем в стиле Heroes of Might & Magic II (клавесин) + 20 симфонических тем:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.45, 0.3, 0.15))
	vbox.add_child(sub)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 410)
	vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

	for i in range(MENU_THEMES.size()):
		if i == 0:
			var sec1 = Label.new()
			sec1.text = "── 🏰 ТЕМЫ В СТИЛЕ HEROES OF MIGHT & MAGIC II (КЛАВЕСИН И РЕНЕССАНС) ──"
			sec1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sec1.add_theme_font_size_override("font_size", 15)
			sec1.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
			list_vbox.add_child(sec1)
		elif i == 20:
			var sec2 = Label.new()
			sec2.text = "── 🎻 СИМФОНИЧЕСКИЕ И СКАЗОЧНЫЕ ТЕМЫ (HMM3 & ОРКЕСТР) ──"
			sec2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sec2.add_theme_font_size_override("font_size", 15)
			sec2.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			list_vbox.add_child(sec2)

		var t_info = MENU_THEMES[i]
		var row = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_vbox.add_child(row)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)

		var play_btn = Button.new()
		play_btn.text = "▶ Играть"
		play_btn.custom_minimum_size = Vector2(100, 48)
		var t_idx = i
		var t_path = t_info["file"]
		play_btn.pressed.connect(func():
			_play_theme_by_index(t_idx)
		)
		hbox.add_child(play_btn)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var name_lbl = Label.new()
		name_lbl.text = t_info["name"]
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		info_vbox.add_child(name_lbl)

		var mood_lbl = Label.new()
		mood_lbl.text = t_info["mood"]
		mood_lbl.add_theme_font_size_override("font_size", 12)
		mood_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(mood_lbl)

		var select_btn = Button.new()
		select_btn.text = "★ Сделать основной"
		select_btn.custom_minimum_size = Vector2(180, 48)
		select_btn.pressed.connect(func():
			SoundManager.play_sfx("coin")
			SoundManager.save_music_preference(t_path)
			_play_theme_by_index(t_idx)
		)
		hbox.add_child(select_btn)

	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.custom_minimum_size = Vector2(180, 52)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		music_dialog.hide()
	)
	vbox.add_child(close_btn)

func _play_theme_by_index(idx: int) -> void:
	current_theme_idx = clamp(idx, 0, MENU_THEMES.size() - 1)
	var t_info = MENU_THEMES[current_theme_idx]
	SoundManager.play_music(t_info["file"], true)
	_update_mini_player_text()

func _open_music_dialog() -> void:
	SoundManager.play_sfx("page_turn")
	music_dialog.show()

# 4. Arena / Demo Battle Setup UI
func _setup_arena_dialog_ui() -> void:
	var m = _create_modal_dialog("ArenaSetupDialog", Vector2(1080, 700))
	arena_dialog = m["root"]

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	m["margin"].add_child(main_vbox)

	var title = Label.new()
	title.text = "⚔️ ТАКТИЧЕСКИЙ БОЙ (ДЕМОНСТРАЦИОННАЯ АРЕНА)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	main_vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Выберите уровень сложности и настройте составы противоборствующих армий:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.45, 0.3, 0.15))
	main_vbox.add_child(sub)

	# State containers
	var current_diff: Array = ["normal"]
	var current_p_preset: Array = ["balanced"]
	var current_e_preset: Array = ["forest_bandits"]
	var current_player_army: Array = []
	var current_enemy_configs: Array = []
	var enemy_title: Array = ["Лесные Разбойники"]

	# Difficulty Selection Bar
	var diff_box = HBoxContainer.new()
	diff_box.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_box.add_theme_constant_override("separation", 12)
	main_vbox.add_child(diff_box)

	var diff_lbl = Label.new()
	diff_lbl.text = "Сложность:"
	diff_lbl.add_theme_font_size_override("font_size", 16)
	diff_lbl.add_theme_color_override("font_color", Color(0.35, 0.22, 0.1))
	diff_box.add_child(diff_lbl)

	var diff_btn_map = {}
	var diff_list = [
		{"id": "easy", "name": "🟢 Новобранец (Легко)"},
		{"id": "normal", "name": "🟡 Воитель (Нормально)"},
		{"id": "hard", "name": "🔴 Герой (Сложно)"},
		{"id": "legendary", "name": "💀 Легенда (Кошмар)"}
	]

	# Columns: Player vs Enemy
	var armies_hbox = HBoxContainer.new()
	armies_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	armies_hbox.add_theme_constant_override("separation", 18)
	main_vbox.add_child(armies_hbox)

	# --- Left: Player Army ---
	var p_col = PanelContainer.new()
	p_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	armies_hbox.add_child(p_col)

	var p_vbox = VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 8)
	p_col.add_child(p_vbox)

	var p_header = Label.new()
	p_header.text = "🛡️ ВАШЕ ВОЙСКО"
	p_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_header.add_theme_font_size_override("font_size", 18)
	p_header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	p_vbox.add_child(p_header)

	var p_ctrl = HBoxContainer.new()
	p_ctrl.add_theme_constant_override("separation", 8)
	p_vbox.add_child(p_ctrl)

	var p_preset_opt = OptionButton.new()
	p_preset_opt.add_item("🛡️ Сбалансированный", 0)
	p_preset_opt.add_item("🏹 Стрелковый полк", 1)
	p_preset_opt.add_item("🦅 Небесный полк (Грифоны)", 2)
	p_preset_opt.add_item("🧙 Круг Друидов", 3)
	p_preset_opt.add_item("🎲 Случайный состав", 4)
	p_preset_opt.select(0)
	p_preset_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_ctrl.add_child(p_preset_opt)

	var p_reroll_btn = Button.new()
	p_reroll_btn.text = "🎲 Перемешать"
	p_ctrl.add_child(p_reroll_btn)

	var p_cards_box = VBoxContainer.new()
	p_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p_cards_box.add_theme_constant_override("separation", 6)
	p_vbox.add_child(p_cards_box)

	# --- Right: Enemy Army ---
	var e_col = PanelContainer.new()
	e_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	armies_hbox.add_child(e_col)

	var e_vbox = VBoxContainer.new()
	e_vbox.add_theme_constant_override("separation", 8)
	e_col.add_child(e_vbox)

	var e_header = Label.new()
	e_header.text = "⚔️ ВРАЖЕСКОЕ ВОЙСКО"
	e_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e_header.add_theme_font_size_override("font_size", 18)
	e_header.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	e_vbox.add_child(e_header)

	var e_ctrl = HBoxContainer.new()
	e_ctrl.add_theme_constant_override("separation", 8)
	e_vbox.add_child(e_ctrl)

	var e_preset_opt = OptionButton.new()
	e_preset_opt.add_item("🌲 Лесные разбойники", 0)
	e_preset_opt.add_item("💀 Болотная нежить", 1)
	e_preset_opt.add_item("🔥 Огненные стражи (Дракон)", 2)
	e_preset_opt.add_item("⚔️ Мятежная гвардия", 3)
	e_preset_opt.add_item("🎲 Случайный противник", 4)
	e_preset_opt.select(0)
	e_preset_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e_ctrl.add_child(e_preset_opt)

	var e_reroll_btn = Button.new()
	e_reroll_btn.text = "🎲 Другой враг"
	e_ctrl.add_child(e_reroll_btn)

	var e_cards_box = VBoxContainer.new()
	e_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	e_cards_box.add_theme_constant_override("separation", 6)
	e_vbox.add_child(e_cards_box)

	# Card Renderer
	var render_ui = func():
		# Refresh diff buttons highlight
		for d in diff_btn_map.keys():
			var btn: Button = diff_btn_map[d]
			if d == current_diff[0]:
				btn.modulate = Color(1.0, 0.9, 0.4)
			else:
				btn.modulate = Color(0.8, 0.8, 0.8)

		# Render Player cards
		for c in p_cards_box.get_children():
			c.queue_free()
		for item in current_player_army:
			var udata = UnitData.get_unit(item["unit_id"])
			var card = PanelContainer.new()
			var hb = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			card.add_child(hb)

			var token = TextureRect.new()
			token.custom_minimum_size = Vector2(44, 44)
			token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_p = udata.get("token_path", "")
			if ResourceLoader.exists(icon_p):
				token.texture = load(icon_p)
			hb.add_child(token)

			var vb = VBoxContainer.new()
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var name_l = Label.new()
			name_l.text = tr("%s: %d воинов") % [tr(udata.get("name", item["unit_id"])), item["count"]]
			name_l.add_theme_font_size_override("font_size", 15)
			name_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
			vb.add_child(name_l)

			var trait_l = Label.new()
			var traits = []
			if udata.get("is_ranged", false):
				traits.append(tr("Стрелок"))
			if udata.get("flying", false):
				traits.append(tr("Летун"))
			if udata.get("unlimited_retaliation", false):
				traits.append(tr("Бесконечный отпор"))
			if udata.get("double_shot", false):
				traits.append(tr("Двойной выстрел"))
			trait_l.text = " • ".join(traits) if traits.size() > 0 else tr("Пехота ближнего боя")
			trait_l.add_theme_font_size_override("font_size", 12)
			trait_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			vb.add_child(trait_l)
			hb.add_child(vb)
			p_cards_box.add_child(card)

		# Render Enemy cards
		for c in e_cards_box.get_children():
			c.queue_free()
		for item in current_enemy_configs:
			var udata = UnitData.get_unit(item["unit_id"])
			var card = PanelContainer.new()
			var hb = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			card.add_child(hb)

			var token = TextureRect.new()
			token.custom_minimum_size = Vector2(44, 44)
			token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_p = udata.get("token_path", "")
			if ResourceLoader.exists(icon_p):
				token.texture = load(icon_p)
			hb.add_child(token)

			var vb = VBoxContainer.new()
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var name_l = Label.new()
			name_l.text = tr("%s: %d воинов") % [tr(udata.get("name", item["unit_id"])), item["count"]]
			name_l.add_theme_font_size_override("font_size", 15)
			name_l.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
			vb.add_child(name_l)

			var trait_l = Label.new()
			var traits = []
			if udata.get("is_ranged", false):
				traits.append(tr("Стрелок"))
			if udata.get("flying", false):
				traits.append(tr("Летун"))
			if udata.get("unlimited_retaliation", false):
				traits.append(tr("Бесконечный отпор"))
			trait_l.text = " • ".join(traits) if traits.size() > 0 else tr("Пехота ближнего боя")
			trait_l.add_theme_font_size_override("font_size", 12)
			trait_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			vb.add_child(trait_l)
			hb.add_child(vb)
			e_cards_box.add_child(card)

	var update_armies = func():
		current_player_army.clear()
		for x in GameState.get_demo_player_preset_army(current_p_preset[0], current_diff[0]):
			current_player_army.append(x)
		current_enemy_configs.clear()
		for x in GameState.get_demo_enemy_preset_army(current_e_preset[0], current_diff[0]):
			current_enemy_configs.append(x)
		render_ui.call()

	# Connect difficulty buttons
	for opt in diff_list:
		var d_btn = Button.new()
		d_btn.text = opt["name"]
		d_btn.custom_minimum_size = Vector2(180, 46)
		d_btn.add_theme_font_size_override("font_size", 15)
		var did = opt["id"]
		d_btn.pressed.connect(func():
			SoundManager.play_sfx("click")
			current_diff[0] = did
			update_armies.call()
		)
		diff_box.add_child(d_btn)
		diff_btn_map[did] = d_btn

	# Connect preset dropdowns
	p_preset_opt.item_selected.connect(func(idx: int):
		SoundManager.play_sfx("click")
		match idx:
			0: current_p_preset[0] = "balanced"
			1: current_p_preset[0] = "shooters"
			2: current_p_preset[0] = "flyers"
			3: current_p_preset[0] = "druids"
			_: current_p_preset[0] = "random"
		update_armies.call()
	)

	p_reroll_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		current_p_preset[0] = "random"
		p_preset_opt.select(4)
		update_armies.call()
	)

	e_preset_opt.item_selected.connect(func(idx: int):
		SoundManager.play_sfx("click")
		match idx:
			0:
				current_e_preset[0] = "forest_bandits"
				enemy_title[0] = "Лесные Разбойники"
			1:
				current_e_preset[0] = "swamp_undead"
				enemy_title[0] = "Болотная Нежить"
			2:
				current_e_preset[0] = "dragon_cult"
				enemy_title[0] = "Культ Дракона"
			3:
				current_e_preset[0] = "rebel_guard"
				enemy_title[0] = "Мятежная Гвардия"
			_:
				current_e_preset[0] = "random"
				enemy_title[0] = "Случайный Отряд Врага"
		update_armies.call()
	)

	e_reroll_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		current_e_preset[0] = "random"
		enemy_title[0] = "Случайный Отряд Врага"
		e_preset_opt.select(4)
		update_armies.call()
	)

	# Initial army population
	update_armies.call()

	# Bottom Actions
	var act_hbox = HBoxContainer.new()
	act_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	act_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(act_hbox)

	var start_fight_btn = Button.new()
	start_fight_btn.text = "⚔️ В БОЙ НА АРЕНУ!"
	start_fight_btn.custom_minimum_size = Vector2(260, 56)
	start_fight_btn.add_theme_font_size_override("font_size", 20)
	start_fight_btn.pressed.connect(func():
		SoundManager.play_sfx("sword_hit")
		GameState.is_demo_battle = true
		GameState.demo_difficulty = current_diff[0]
		GameState.demo_difficulty_title = GameState.get_difficulty_multipliers(current_diff[0])["title"]
		GameState.demo_player_army.clear()
		for x in current_player_army:
			GameState.demo_player_army.append(x.duplicate())
		GameState.demo_enemy_configs.clear()
		for x in current_enemy_configs:
			GameState.demo_enemy_configs.append(x.duplicate())
		GameState.demo_encounter_title = enemy_title[0]
		GameState.battle_return_scene = "res://src/main.tscn"
		get_tree().change_scene_to_file("res://src/battle/battle_arena.tscn")
	)
	act_hbox.add_child(start_fight_btn)

	var close_btn = Button.new()
	close_btn.text = "Назад"
	close_btn.custom_minimum_size = Vector2(180, 56)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		arena_dialog.hide()
	)
	act_hbox.add_child(close_btn)

func _open_arena_dialog() -> void:
	SoundManager.play_sfx("page_turn")
	arena_dialog.show()

func _on_arena_battle() -> void:
	_open_arena_dialog()

# 5. About Dialog UI
func _setup_about_dialog_ui() -> void:
	var m = _create_modal_dialog("AboutDialog", Vector2(820, 560))
	about_dialog = m["root"]

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	m["margin"].add_child(vbox)

	var title = Label.new()
	title.text = "О ПРОЕКТЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	var text = Label.new()
	text.text = "«Сказки Королевства» — ламповая сказочная RPG, вдохновленная классикой Heroes of Might and Magic 3 и King's Bounty («Легенда о рыцаре»).\n\nОсобенности игры:\n• Никаких скучных замков и рутины строительства!\n• Уютные сказочные персонажи, водяные мельницы и сундуки с сокровищами.\n• Тактические пошаговые бои на гексах с живой книгой магии героя.\n• 40 уникальных музыкальных тем (клавесин HoMM2 и оркестровая классика).\n• Полная поддержка мобильного управления и сенсорных экранов!"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", Color(0.22, 0.14, 0.06))
	vbox.add_child(text)

	var close_btn = Button.new()
	close_btn.text = "Назад"
	close_btn.custom_minimum_size = Vector2(180, 52)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		about_dialog.hide()
	)
	vbox.add_child(close_btn)

# 6. Настройки: громкость + язык
func _open_settings_dialog() -> void:
	SoundManager.play_sfx("page_turn")
	_build_settings_dialog().show()

func _build_settings_dialog() -> Control:
	var root = _create_modal_dialog("SettingsDialog", Vector2(520, 420))
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	root["margin"].add_child(vbox)

	var title = Label.new()
	title.text = tr("⚙️ НАСТРОЙКИ")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	for cfg in [["Общая громкость:", SettingsManager.master_volume,
			func(v: float): SettingsManager.master_volume = v],
			["Музыка:", SettingsManager.music_volume,
			func(v: float): SettingsManager.music_volume = v],
			["Звуки:", SettingsManager.sfx_volume,
			func(v: float): SettingsManager.sfx_volume = v]]:
		var box = HBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		var lbl = Label.new()
		lbl.text = tr(cfg[0])
		lbl.custom_minimum_size = Vector2(180, 0)
		lbl.add_theme_color_override("font_color", Color(0.35, 0.22, 0.1))
		var slider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = cfg[1]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v: float):
			cfg[2].call(v)
			SettingsManager.apply()
			SettingsManager.save_settings()
		)
		box.add_child(lbl)
		box.add_child(slider)
		vbox.add_child(box)

	var lang_box = HBoxContainer.new()
	var lang_lbl = Label.new()
	lang_lbl.text = tr("Язык:")
	lang_lbl.custom_minimum_size = Vector2(180, 0)
	lang_lbl.add_theme_color_override("font_color", Color(0.35, 0.22, 0.1))
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
	vbox.add_child(lang_box)

	var anim_chk := CheckButton.new()
	anim_chk.text = tr("Упрощённые анимации (для слабых устройств)")
	anim_chk.button_pressed = SettingsManager.reduced_animations
	anim_chk.add_theme_color_override("font_color", Color(0.35, 0.22, 0.1))
	anim_chk.toggled.connect(func(on: bool):
		SettingsManager.reduced_animations = on
		SettingsManager.save_settings()
	)
	vbox.add_child(anim_chk)

	vbox.add_spacer(false)

	var close_btn = Button.new()
	close_btn.text = tr("Закрыть")
	close_btn.custom_minimum_size = Vector2(180, 52)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		root["root"].hide()
	)
	vbox.add_child(close_btn)
	return root["root"]

# 7. Летопись подвигов (главное меню)
func _open_chronicle_dialog() -> void:
	SoundManager.play_sfx("page_turn")
	_build_chronicle_dialog().show()

func _build_chronicle_dialog() -> Control:
	var root = _create_modal_dialog("ChronicleDialog", Vector2(640, 620))
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	root["margin"].add_child(vbox)

	var title = Label.new()
	title.text = tr("📜 ЛЕТОПИСЬ ПОДВИГОВ")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = tr("Открыто подвигов: %d из %d") % [GameState.chronicle.size(), GameState.CHRONICLE_DEFS.size()]
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

	var close_btn = Button.new()
	close_btn.text = tr("Закрыть")
	close_btn.custom_minimum_size = Vector2(180, 46)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		root["root"].hide()
	)
	vbox.add_child(close_btn)
	return root["root"]

# 8. Кодекс существ (бестиарий)
func _open_bestiary_dialog() -> void:
	SoundManager.play_sfx("page_turn")
	_build_bestiary_dialog().show()

func _build_bestiary_dialog() -> Control:
	var root = _create_modal_dialog("BestiaryDialog", Vector2(720, 640))
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	root["margin"].add_child(vbox)

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

	var close_btn = Button.new()
	close_btn.text = tr("Закрыть")
	close_btn.custom_minimum_size = Vector2(180, 46)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		SoundManager.play_sfx("click")
		root["root"].hide()
	)
	vbox.add_child(close_btn)
	return root["root"]

func _on_about() -> void:
	SoundManager.play_sfx("page_turn")
	about_dialog.show()

# Android hardware back button & system navigation
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()

func _handle_back_request() -> void:
	if arena_dialog != null and arena_dialog.visible:
		arena_dialog.hide()
	elif chapter_dialog != null and chapter_dialog.visible:
		chapter_dialog.hide()
	elif hero_select_dialog != null and hero_select_dialog.visible:
		hero_select_dialog.hide()
	elif music_dialog != null and music_dialog.visible:
		music_dialog.hide()
	elif about_dialog != null and about_dialog.visible:
		about_dialog.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_handle_back_request()
		elif event.keycode == KEY_LEFT:
			var next_idx = (current_theme_idx - 1 + MENU_THEMES.size()) % MENU_THEMES.size()
			_play_theme_by_index(next_idx)
		elif event.keycode == KEY_RIGHT:
			var next_idx = (current_theme_idx + 1) % MENU_THEMES.size()
			_play_theme_by_index(next_idx)
