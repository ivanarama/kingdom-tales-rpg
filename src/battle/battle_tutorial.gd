class_name BattleTutorial
extends PanelContainer

## Обучение в первом бою кампании: пять подсказок внизу поля. Шаг сменяется сам,
## когда игрок сделал то, о чём подсказка (сходил, ударил, сотворил заклинание),
## или по кнопке «Дальше». Показывается один раз: флаг хранится в настройках,
## потому что флаги кампании сбрасываются с каждой главой.

const STEPS := [
	"Сейчас ходит отряд на золотой клетке. Синие клетки — куда он может пойти: нажмите на любую.",
	"Наведите курсор на врага — над ним появится прогноз урона и потерь, щелчок — атака. На телефоне первое касание показывает прогноз, второе — атакует.",
	"Стрелки бьют издалека, но дальше 5 клеток — вполсилы («сломанная стрела»). Враг вплотную к стрелку мешает ему стрелять.",
	"Книга магии — кнопка справа внизу: герой творит одно заклинание за раунд, и ход отряда на это не тратится.",
	"«Ждать» — сходить позже в этом раунде, «Защита» — +30% к защите до следующего хода. Удачи, полководец!",
]

var arena: BattleArena
var step := 0
var _title: Label
var _text: Label
var _next_btn: Button
# состояние на начало шага — чтобы заметить, что игрок сделал нужное
var _actor_at_step: BattleStack
var _hex_at_step := Vector2i.ZERO
var _dealt_at_step := 0
var _round_at_step := 1

## Обучение нужно в кампании, пока его не прошли; на Арене — нет.
static func should_show() -> bool:
	return not SettingsManager.battle_tutorial_done and not GameState.is_demo_battle

func setup(p_arena: BattleArena) -> void:
	arena = p_arena
	name = "BattleTutorial"
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -440.0
	offset_right = 440.0
	offset_top = -226.0
	offset_bottom = -128.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.91, 0.78, 0.96)
	style.border_color = Color(0.85, 0.68, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", Color(0.6, 0.38, 0.08))
	col.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_color_override("font_color", Color(0.22, 0.13, 0.05))
	col.add_child(_text)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(150, 40)
	_next_btn.pressed.connect(next_step)
	buttons.add_child(_next_btn)
	var skip_btn := Button.new()
	skip_btn.text = "Пропустить обучение"
	skip_btn.flat = true
	skip_btn.add_theme_font_size_override("font_size", 12)
	# у плоской кнопки светлый цвет темы теряется на пергаменте
	skip_btn.add_theme_color_override("font_color", Color(0.45, 0.3, 0.12))
	skip_btn.add_theme_color_override("font_hover_color", Color(0.65, 0.4, 0.1))
	skip_btn.add_theme_color_override("font_pressed_color", Color(0.3, 0.18, 0.06))
	skip_btn.pressed.connect(finish)
	buttons.add_child(skip_btn)
	_show_step()

func _show_step() -> void:
	_title.text = tr("📜 Совет полководца (%d/%d)") % [step + 1, STEPS.size()]
	_text.text = tr(STEPS[step])
	_next_btn.text = tr("Понятно") if step == STEPS.size() - 1 else tr("Дальше ›")
	_actor_at_step = arena.current_actor
	_hex_at_step = arena.current_actor.hex if arena.current_actor else Vector2i.ZERO
	_dealt_at_step = int(arena.battle_stats.get("dealt", 0))
	_round_at_step = arena.current_round

func next_step() -> void:
	SoundManager.play_sfx("page_turn")
	step += 1
	if step >= STEPS.size():
		finish()
	else:
		_show_step()

func finish() -> void:
	SettingsManager.battle_tutorial_done = true
	SettingsManager.save_settings()
	queue_free()

## Шаг сменяется сам, когда игрок сделал то, о чём подсказка.
func _process(_delta: float) -> void:
	if arena == null or not is_instance_valid(arena):
		return
	var done := false
	match step:
		0:
			# ждём хода именно отряда игрока: бой может начать враг
			if _actor_at_step == null or _actor_at_step.team != 0:
				if arena.current_actor != null and arena.current_actor.team == 0:
					_actor_at_step = arena.current_actor
					_hex_at_step = _actor_at_step.hex
			else:
				done = _actor_at_step.hex != _hex_at_step or _actor_at_step.has_acted
		1:
			done = int(arena.battle_stats.get("dealt", 0)) > _dealt_at_step
		2:
			done = arena.current_round > _round_at_step
		3:
			done = arena.hero_cast_this_round
	if done:
		next_step()
