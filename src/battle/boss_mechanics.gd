class_name BossMechanics
extends RefCounted

## Способности боссов в тактическом бою. Заданы полями существ в UnitData, поэтому
## действуют в любом бою, где встречается существо (кампания и Арена):
##   rally_aura: int — Атаман: пока отряд жив, остальные отряды его стороны получают +N к атаке;
##   raise_dead: {unit, per_unit, every} — Лич: в начале раундов 1 + every·k (3-го, 5-го…)
##       поднимает per_unit существ unit за каждого лича в отряде;
##   firestorm: int — Дракон: в раундах 2, 5, 8… набирает воздух и помечает конус длиной N клеток,
##       а следующим своим ходом выжигает его. Клетки видны заранее — отряды можно увести.
## BattleArena зовёт on_round_start, before_turn, plan_turn/take_turn и turn_hint;
## ArenaViewport — draw_ground (под отрядами) и draw_overlay (поверх).

const FIRESTORM_FIRST_ROUND := 2
const FIRESTORM_EVERY := 3
const FIRESTORM_DAMAGE := 1.5 # от обычной атаки: вдох стоит дракону целого хода
const CONE_HALF_ANGLE := 30.5 * PI / 180.0 # клетки ровно на границе 30° входят в конус
const FLAME_TIME := 1.0
const FLAME_PEAK := 0.3 # урон — в миг, когда пламя выше всего
const COLOR_NECRO := Color(0.72, 0.42, 1.0)
const COLOR_FIRE := Color(1.0, 0.45, 0.1)
const COLOR_BANNER := Color(0.72, 0.1, 0.08)
const COLOR_GOLD := Color(0.95, 0.78, 0.3)
const COLOR_WOOD := Color(0.3, 0.19, 0.1)

var arena: BattleArena
var charged: Dictionary = {} # дракон (BattleStack) -> Array[Vector2i]: клетки, которые он выжжет следующим ходом
var _plans: Dictionary = {} # дракон -> {hex, cells}: вдох, выбранный plan_turn
var _flames: Array = [] # вспышки пламени после выдоха: {pos, start}

func _init(p_arena: BattleArena) -> void:
	arena = p_arena

# --- Хуки хода боя ---

## Начало раунда: личи поднимают нежить. Зовётся до сборки очереди,
## поэтому поднятые отряды ходят уже в этом раунде.
func on_round_start() -> void:
	for s in arena.all_stacks.duplicate():
		if s.is_alive() and s.data.has("raise_dead") and _is_raise_round(s, arena.current_round):
			_raise_dead(s)
	before_turn()

## Перед каждым ходом: пересчитать знамя вожака (гибель Атамана снимает прибавку
## со следующего же хода) и забыть заряд павшего дракона.
func before_turn() -> void:
	var best := {0: 0, 1: 0}
	for s in arena.all_stacks:
		if s.is_alive():
			best[s.team] = maxi(int(best.get(s.team, 0)), int(s.data.get("rally_aura", 0)))
	for s in arena.all_stacks:
		# Сам вожак прибавку не получает
		s.aura_attack = 0 if int(s.data.get("rally_aura", 0)) > 0 else int(best.get(s.team, 0))
	for dragon in charged.keys():
		if not dragon.is_alive():
			charged.erase(dragon)

## Займёт ли способность ход отряда: выдох заряженного дракона или вдох в раунд шквала.
## true — ход сделает take_turn(), обычный ИИ не нужен.
func plan_turn(actor: BattleStack) -> bool:
	_plans.erase(actor)
	if int(actor.data.get("firestorm", 0)) <= 0:
		return false
	if charged.has(actor):
		return true
	if not is_firestorm_round(arena.current_round):
		return false
	var plan := _best_breath(actor)
	if plan.is_empty():
		return false
	_plans[actor] = plan
	return true

func take_turn(actor: BattleStack) -> void:
	if charged.has(actor):
		await _exhale(actor)
	elif _plans.has(actor):
		var plan: Dictionary = _plans[actor]
		_plans.erase(actor)
		await _inhale(actor, plan)

## Строка хода для отряда, стоящего там, куда дохнёт дракон; "" — отряд вне огня.
func turn_hint(actor: BattleStack) -> String:
	for dragon in charged.keys():
		if dragon.is_alive() and charged[dragon].has(actor.hex):
			return arena.tr("🔥 %s под огнём дракона — уходите с отмеченных клеток!") % arena.tr(actor.data.name)
	return ""

## Через сколько раундов лич поднимет нежить: 1 — в начале следующего раунда.
func rounds_until_raise(stack: BattleStack) -> int:
	var every := _raise_every(stack)
	return every - (arena.current_round - 1) % every

static func is_firestorm_round(round_no: int) -> bool:
	return round_no >= FIRESTORM_FIRST_ROUND and (round_no - FIRESTORM_FIRST_ROUND) % FIRESTORM_EVERY == 0

## Клетки конуса длиной length от origin в сторону dir (одно из HexGrid.DIRECTIONS):
## не дальше length и в пределах ±30° от направления — ряды по 1, 3 и 3 клетки.
static func cone_cells(origin: Vector2i, dir: Vector2i, length: int, bounds: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var o := HexGrid.hex_to_pixel(origin.x, origin.y, 1.0, Vector2.ZERO)
	var aim := HexGrid.hex_to_pixel(dir.x, dir.y, 1.0, Vector2.ZERO)
	for r in range(origin.y - length, origin.y + length + 1):
		for q in range(origin.x - length, origin.x + length + 1):
			var h := Vector2i(q, r)
			var d := HexGrid.distance(origin, h)
			if d < 1 or d > length or not HexGrid.is_in_bounds(h, bounds):
				continue
			var v := HexGrid.hex_to_pixel(q, r, 1.0, Vector2.ZERO) - o
			if absf(aim.angle_to(v)) <= CONE_HALF_ANGLE:
				result.append(h)
	return result

## Строки способностей для карточки отряда в бою (подробности — в описании существа).
func trait_lines(data: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var aura := int(data.get("rally_aura", 0))
	if aura > 0:
		lines.append(arena.tr("Знамя вожака (+%d к атаке союзников)") % aura)
	if data.has("raise_dead"):
		lines.append(arena.tr("Подъём нежити (раз в %d р.)") % int(data["raise_dead"].get("every", 2)))
	if int(data.get("firestorm", 0)) > 0:
		lines.append(arena.tr("Огненный шквал (раз в %d р.)") % FIRESTORM_EVERY)
	return lines

# --- Лич ---

func _raise_every(stack: BattleStack) -> int:
	return maxi(1, int(stack.data["raise_dead"].get("every", 2)))

func _is_raise_round(stack: BattleStack, round_no: int) -> bool:
	return round_no > 1 and (round_no - 1) % _raise_every(stack) == 0

## Поднятые встают в строй к живому отряду того же вида, а если его нет —
## новым отрядом на ближайшей к личу свободной клетке.
func _raise_dead(lich: BattleStack) -> void:
	var cfg: Dictionary = lich.data["raise_dead"]
	var unit_id := str(cfg.get("unit", "skeleton_archer"))
	var amount := lich.count * int(cfg.get("per_unit", 1))
	if amount <= 0 or UnitData.get_unit(unit_id).is_empty():
		return
	var raised: BattleStack = null
	for s in arena.all_stacks:
		if s.is_alive() and s.team == lich.team and s.unit_id == unit_id:
			raised = s
			break
	if raised != null:
		raised.count += amount
	else:
		var hex := _free_hex_near(lich.hex)
		if hex.x < 0:
			return
		raised = BattleStack.new()
		raised.setup(unit_id, amount, lich.team, hex)
		arena.all_stacks.append(raised)
	arena.arena_viewport.spawn_holy_halo(_hex_center(raised.hex), COLOR_NECRO)
	arena._spawn_floating_text(raised.hex, "💀 +%d" % amount, COLOR_NECRO)
	SoundManager.play_sfx("spell_cast")
	arena.log_combat(arena.tr("💀 %s поднимает нежить: %s +%d!") % [
		arena.tr(lich.data.name), arena.tr(raised.data.name), amount
	])

## Ближайшая к origin свободная клетка поля; (-1, -1), если мест нет.
func _free_hex_near(origin: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 1 << 30
	var b: Rect2i = arena.field_bounds
	for r in range(b.position.y, b.end.y):
		for q in range(b.position.x, b.end.x):
			var h := Vector2i(q, r)
			var d := HexGrid.distance(origin, h)
			if d == 0 or d >= best_dist or arena.obstacles.has(h) or _stack_at(h) != null:
				continue
			best = h
			best_dist = d
	return best

func _stack_at(hex: Vector2i) -> BattleStack:
	for s in arena.all_stacks:
		if s.is_alive() and s.hex == hex:
			return s
	return null

# --- Дракон ---

## Лучший вдох: из клеток, куда дракон долетит этим ходом, и шести направлений
## выбираем конус, накрывающий больше всего здоровья вражеских отрядов.
func _best_breath(actor: BattleStack) -> Dictionary:
	var length := int(actor.data.get("firestorm", 3))
	var spots: Array[Vector2i] = [actor.hex]
	if actor == arena.current_actor:
		spots.append_array(arena.reachable_hexes)
	var best := {}
	var best_score := 0.0
	for spot in spots:
		for dir in HexGrid.DIRECTIONS:
			var cells := cone_cells(spot, dir, length, arena.field_bounds)
			var score := 0.0
			for s in arena.all_stacks:
				if s.is_alive() and s.team != actor.team and cells.has(s.hex):
					score += float(_hp_pool(s))
			if score <= 0.0:
				continue
			score -= 0.5 * HexGrid.distance(actor.hex, spot) # при равном улове — меньше лететь
			if score > best_score:
				best_score = score
				best = {"hex": spot, "cells": cells}
	return best

func _inhale(actor: BattleStack, plan: Dictionary) -> void:
	var spot: Vector2i = plan["hex"]
	if spot != actor.hex:
		actor.hex = spot
		arena.arena_viewport.queue_redraw()
		await arena.get_tree().create_timer(0.35).timeout
		if not is_instance_valid(arena):
			return
	charged[actor] = plan["cells"]
	SoundManager.play_sfx("spell_cast")
	arena._spawn_floating_text(actor.hex, "🔥 ВДОХ!", COLOR_FIRE)
	arena.log_combat(arena.tr("🔥 %s набирает воздух — уведите отряды с отмеченных клеток!") % arena.tr(actor.data.name))
	arena.arena_viewport.queue_redraw()
	await arena.get_tree().create_timer(0.6).timeout

## Выдох: урон — через общую точку _resolve_attack_damage (щит, статистика боя).
func _exhale(actor: BattleStack) -> void:
	var cells: Array = charged[actor]
	charged.erase(actor)
	SoundManager.play_sfx("spell_cast")
	var now: float = arena.arena_viewport.anim_timer
	for c in cells:
		_flames.append({"pos": _hex_center(c), "start": now})
	await arena.get_tree().create_timer(FLAME_PEAK).timeout
	if not is_instance_valid(arena):
		return
	var hits := 0
	for s in arena.all_stacks:
		if not (s.is_alive() and s.team != actor.team and cells.has(s.hex)):
			continue
		var dmg := int(actor.calculate_attack_damage(s, true) * FIRESTORM_DAMAGE)
		var res: Dictionary = arena._resolve_attack_damage(actor, s, dmg, false)
		arena.arena_viewport.flash_stack(s)
		arena._spawn_floating_text(s.hex, "🔥 -%d" % int(res["damage"]), COLOR_FIRE)
		if int(res["casualties"]) > 0:
			arena._spawn_floating_text(s.hex, arena.tr("Потери: -%d") % int(res["casualties"]), Color(1.0, 0.1, 0.1), Vector2(0, -28))
		hits += 1
	if hits == 0:
		arena.log_combat("🔥 Огненный шквал бьёт в пустоту — все успели уйти!")
	else:
		arena.log_combat(arena.tr("🔥 Огненный шквал обрушивается на отряды: %d!") % hits)
	arena.arena_viewport.queue_redraw()
	await arena.get_tree().create_timer(FLAME_TIME - FLAME_PEAK).timeout

static func _hp_pool(s: BattleStack) -> int:
	return (s.count - 1) * int(s.data.get("max_hp", 20)) + s.current_hp

# --- Отрисовка ---

func _hex_center(hex: Vector2i) -> Vector2:
	return HexGrid.hex_to_pixel(hex.x, hex.y, BattleArena.HEX_SIZE, arena.grid_origin)

## Под отрядами: клетки шквала, круги рун под личами, знамя вожака.
func draw_ground(vp: ArenaViewport) -> void:
	var t := vp.anim_timer
	for dragon in charged.keys():
		if dragon.is_alive():
			for c in charged[dragon]:
				_draw_fire_cell(vp, _hex_center(c), t)
	for s in arena.all_stacks:
		if not s.is_alive():
			continue
		var center := _hex_center(s.hex) + vp.get_stack_offset(s)
		if s.data.has("raise_dead"):
			_draw_rune_circle(vp, center + Vector2(0, BattleArena.HEX_SIZE * 0.45), t, rounds_until_raise(s) == 1)
		if int(s.data.get("rally_aura", 0)) > 0:
			_draw_banner(vp, center, t)

## Поверх отрядов: отсчёт до ритуала лича и вспышки пламени.
## Прибавку от знамени показывает красный пипс в ряду индикаторов чар (ArenaViewport).
func draw_overlay(vp: ArenaViewport) -> void:
	var t := vp.anim_timer
	for s in arena.all_stacks:
		if s.is_alive() and s.data.has("raise_dead") and vp.stack_anchors.has(s):
			_draw_countdown(vp, vp.stack_anchors[s] + Vector2(42, 0), rounds_until_raise(s))
	_flames = _flames.filter(func(f): return t - float(f["start"]) < FLAME_TIME)
	for f in _flames:
		_draw_flame_burst(vp, f["pos"], (t - float(f["start"])) / FLAME_TIME)

func _draw_fire_cell(vp: ArenaViewport, center: Vector2, t: float) -> void:
	var size := BattleArena.HEX_SIZE
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	var pts := HexGrid.get_hex_points(center, size - 3.0)
	vp.draw_colored_polygon(pts, Color(1.0, 0.3, 0.02, 0.4 + 0.2 * pulse))
	var outline := pts.duplicate()
	outline.append(pts[0])
	vp.draw_polyline(outline, Color(1.0, 0.5, 0.08, 1.0), 4.0, true)
	vp.draw_polyline(outline, Color(1.0, 0.9, 0.45, 0.5 + 0.4 * pulse), 1.5, true)
	var base := center + Vector2(0, size * 0.3)
	_draw_flame(vp, base, size * (0.5 + 0.06 * pulse), Color(1.0, 0.45, 0.08, 0.8))
	_draw_flame(vp, base, size * 0.28, Color(1.0, 0.88, 0.35, 0.9))

func _draw_flame_burst(vp: ArenaViewport, pos: Vector2, k: float) -> void:
	var size := BattleArena.HEX_SIZE
	var rise := minf(1.0, k / (FLAME_PEAK / FLAME_TIME)) # пламя взмывает к пику, во второй половине гаснет
	var fade := clampf((1.0 - k) / 0.5, 0.0, 1.0)
	var base := pos + Vector2(0, size * 0.45)
	vp.draw_circle(pos + Vector2(0, size * 0.2), size * (0.5 + 0.35 * rise), Color(1.0, 0.35, 0.02, 0.35 * fade))
	for i in 3:
		var dx := (float(i) - 1.0) * size * 0.34
		var h := size * (1.5 - 0.35 * absf(float(i) - 1.0)) * rise * (0.9 + 0.1 * sin(k * 20.0 + float(i)))
		_draw_flame(vp, base + Vector2(dx, 0), h, Color(1.0, 0.38, 0.04, 0.9 * fade))
		_draw_flame(vp, base + Vector2(dx, 0), h * 0.6, Color(1.0, 0.8, 0.25, fade))

## Язык пламени: круглое основание и острый кончик вверх; base — нижняя точка.
static func _draw_flame(vp: CanvasItem, base: Vector2, height: float, color: Color) -> void:
	if height < 1.0:
		return # вырожденный многоугольник не триангулируется
	var r := height / 3.2
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var x := sin(a)
		var y := cos(a) # 1 — низ, -1 — верх
		if y < 0.0:
			x *= 1.0 + y * 0.55
			y *= 2.2
		pts.append(base + Vector2(x * r, (y - 1.0) * r))
	vp.draw_colored_polygon(pts, color)

## Круг рун на земле под личом: вращается, а перед ритуалом пульсирует.
func _draw_rune_circle(vp: ArenaViewport, ground: Vector2, t: float, imminent: bool) -> void:
	var r := BattleArena.HEX_SIZE * 1.05
	var alpha := 0.75
	if imminent:
		alpha = 0.7 + 0.3 * (0.5 + 0.5 * sin(t * 6.0))
	var col := Color(COLOR_NECRO, alpha)
	var rot := t * 0.8
	vp.draw_set_transform(ground, 0.0, Vector2(1.0, 0.42))
	vp.draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 48, Color(COLOR_NECRO, alpha * 0.3), 10.0, true)
	vp.draw_arc(Vector2.ZERO, r, rot, rot + TAU * 0.8, 48, col, 3.0, true)
	vp.draw_arc(Vector2.ZERO, r * 0.72, -rot * 1.4, -rot * 1.4 + TAU * 0.75, 36, col, 2.0, true)
	for i in 8:
		var d := Vector2.from_angle(rot + TAU * float(i) / 8.0)
		vp.draw_line(d * r * 0.8, d * r * 0.96, col, 3.0, true)
	vp.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_countdown(vp: ArenaViewport, pos: Vector2, rounds_left: int) -> void:
	vp.draw_circle(pos, 12.0, Color(0.22, 0.07, 0.3, 0.95))
	vp.draw_arc(pos, 12.0, 0.0, TAU, 24, COLOR_NECRO, 2.0, true)
	var font := ThemeDB.fallback_font
	var label := str(rounds_left)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	vp.draw_string(font, pos + Vector2(-w / 2.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 1.0))

## Знамя за вожаком: древко справа от клетки и полотнище-«ласточкин хвост».
func _draw_banner(vp: ArenaViewport, center: Vector2, t: float) -> void:
	var size := BattleArena.HEX_SIZE
	var foot := center + Vector2(size * 0.66, size * 0.32)
	var top := foot - Vector2(0, size * 2.45)
	vp.draw_line(foot, top, COLOR_WOOD, 5.0, true)
	vp.draw_line(foot + Vector2(1.5, 0), top + Vector2(1.5, 0), Color(0.52, 0.36, 0.2), 1.5, true)
	var w := size * 0.95
	var fh := size * 0.7
	var y0 := 6.0
	var pts := PackedVector2Array()
	for i in 7:
		var x := w * float(i) / 6.0
		pts.append(top + Vector2(x, y0 + _wave(t, x)))
	var notch_x := w * 0.74
	pts.append(top + Vector2(notch_x, y0 + fh * 0.5 + _wave(t, notch_x)))
	for i in range(6, -1, -1):
		var x := w * float(i) / 6.0
		pts.append(top + Vector2(x, y0 + fh + _wave(t, x)))
	vp.draw_colored_polygon(pts, COLOR_BANNER)
	var outline := pts.duplicate()
	outline.append(pts[0])
	vp.draw_polyline(outline, COLOR_GOLD, 2.0, true)
	var emblem_x := w * 0.36
	var emblem := top + Vector2(emblem_x, y0 + fh * 0.5 + _wave(t, emblem_x))
	vp.draw_circle(emblem, fh * 0.24, COLOR_GOLD)
	vp.draw_circle(emblem, fh * 0.15, Color(0.42, 0.05, 0.04))
	vp.draw_circle(top, 5.0, COLOR_GOLD)

## Колыхание полотнища: у древка неподвижно, к свободному краю сильнее.
static func _wave(t: float, x: float) -> float:
	return sin(t * 3.2 - x * 0.09) * x * 0.07
