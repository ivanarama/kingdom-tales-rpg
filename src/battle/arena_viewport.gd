class_name ArenaViewport
extends Control

@onready var arena: BattleArena = get_parent()

var sprite_cache: Dictionary = {}
var stack_offsets: Dictionary = {} # BattleStack -> Vector2
var stack_flashes: Dictionary = {} # BattleStack -> float
var projectiles: Array[Dictionary] = [] # [{pos, end_pos, progress, speed, type, on_hit}]
var special_effects: Array[Dictionary] = [] # [{type, pos, time, max_time, on_hit}]

var anim_timer: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS

func set_stack_offset(stack: BattleStack, offset: Vector2) -> void:
	stack_offsets[stack] = offset
	queue_redraw()

func get_stack_offset(stack: BattleStack) -> Vector2:
	return stack_offsets.get(stack, Vector2.ZERO)

func _process(delta: float) -> void:
	anim_timer += delta
	var needs_redraw = true
	
	# Update flash timers
	var to_erase_flash = []
	for s in stack_flashes.keys():
		stack_flashes[s] -= delta
		if stack_flashes[s] <= 0.0:
			to_erase_flash.append(s)
	for s in to_erase_flash:
		stack_flashes.erase(s)
		
	# Update projectiles
	var to_erase_proj = []
	for p in projectiles:
		p.progress += delta * p.speed
		if p.progress >= 1.0:
			to_erase_proj.append(p)
			if p.has("on_hit") and p.on_hit.is_valid():
				p.on_hit.call()
	for p in to_erase_proj:
		projectiles.erase(p)
		
	# Update special effects
	var to_erase_fx = []
	for fx in special_effects:
		fx.time -= delta
		if fx.time <= 0.0:
			to_erase_fx.append(fx)
			if fx.has("on_hit") and fx.on_hit.is_valid():
				fx.on_hit.call()
	for fx in to_erase_fx:
		special_effects.erase(fx)
		
	queue_redraw()

func spawn_arrow(start_pos: Vector2, end_pos: Vector2, on_hit_callback: Callable) -> void:
	projectiles.append({
		"start_pos": start_pos,
		"end_pos": end_pos,
		"progress": 0.0,
		"speed": 5.0,
		"type": "arrow",
		"on_hit": on_hit_callback
	})
	queue_redraw()

func spawn_fireball(start_pos: Vector2, end_pos: Vector2, on_hit_callback: Callable) -> void:
	projectiles.append({
		"start_pos": start_pos,
		"end_pos": end_pos,
		"progress": 0.0,
		"speed": 4.0,
		"type": "fireball",
		"on_hit": on_hit_callback
	})
	queue_redraw()

func spawn_lightning(target_pos: Vector2, on_hit_callback: Callable) -> void:
	special_effects.append({
		"type": "lightning",
		"pos": target_pos,
		"time": 0.28,
		"max_time": 0.28,
		"on_hit": on_hit_callback
	})
	queue_redraw()

func spawn_frost(target_pos: Vector2, on_hit_callback: Callable) -> void:
	special_effects.append({
		"type": "frost",
		"pos": target_pos,
		"time": 0.45,
		"max_time": 0.45,
		"on_hit": on_hit_callback
	})
	queue_redraw()

func spawn_holy_halo(target_pos: Vector2, color: Color = Color(1.0, 0.9, 0.3)) -> void:
	special_effects.append({
		"type": "halo",
		"pos": target_pos,
		"color": color,
		"time": 0.5,
		"max_time": 0.5
	})
	queue_redraw()

func spawn_stoneskin(target_pos: Vector2, on_hit_callback: Callable = Callable()) -> void:
	special_effects.append({
		"type": "stoneskin",
		"pos": target_pos,
		"time": 0.45,
		"max_time": 0.45,
		"on_hit": on_hit_callback
	})
	queue_redraw()

func spawn_blind(target_pos: Vector2, on_hit_callback: Callable = Callable()) -> void:
	special_effects.append({
		"type": "blind",
		"pos": target_pos,
		"time": 0.5,
		"max_time": 0.5,
		"on_hit": on_hit_callback
	})
	queue_redraw()

func flash_stack(stack: BattleStack) -> void:
	stack_flashes[stack] = 0.28
	queue_redraw()

func _draw() -> void:
	if arena == null:
		return
		
	var hex_size = arena.HEX_SIZE
	var origin = arena.grid_origin
	var bounds = arena.field_bounds
	var font = ThemeDB.fallback_font
	
	# 1. Draw Hex Grid
	for r in range(bounds.position.y, bounds.end.y):
		for q in range(bounds.position.x, bounds.end.x):
			var center = HexGrid.hex_to_pixel(q, r, hex_size, origin)
			var points = HexGrid.get_hex_points(center, hex_size - 2.0)
			
			var hex = Vector2i(q, r)
			var is_obs = arena.obstacles.has(hex)
			var is_reachable = arena.reachable_hexes.has(hex)
			var is_active = (arena.current_actor != null and arena.current_actor.hex == hex)
			
			# Hex fill
			if is_active:
				draw_colored_polygon(points, arena.COLOR_ACTIVE_HEX)
			elif is_reachable:
				draw_colored_polygon(points, arena.COLOR_MOVE_REACHABLE)
			elif is_obs:
				draw_colored_polygon(points, Color(0.2, 0.18, 0.15, 0.6))
			elif arena.hovered_threat_hexes.has(hex):
				draw_colored_polygon(points, Color(0.95, 0.2, 0.15, 0.28))
			else:
				draw_colored_polygon(points, arena.COLOR_HEX_FILL)
				
			# Hex border
			var border_color = Color(1.0, 0.95, 0.6, 0.8) if is_active else (Color(1.0, 0.3, 0.25, 0.85) if arena.hovered_threat_hexes.has(hex) else arena.COLOR_HEX_OUTLINE)
			var border_width = 3.0 if (is_active or arena.hovered_threat_hexes.has(hex)) else 1.5
			draw_polyline(points, border_color, border_width, true)
			
			# Obstacle detail
			if is_obs:
				match GameState.current_chapter:
					2:
						# Swamp Tombstone / Ruin
						var tomb_w = hex_size * 0.45
						var tomb_h = hex_size * 0.55
						var t_rect = Rect2(center.x - tomb_w/2.0, center.y - tomb_h/2.0, tomb_w, tomb_h)
						draw_rect(t_rect, Color(0.25, 0.3, 0.28, 0.95), true)
						draw_rect(t_rect, Color(0.15, 0.2, 0.18, 0.95), false, 2.0)
						# Mossy patches
						draw_circle(center + Vector2(-6, 6), 5.0, Color(0.18, 0.45, 0.22, 0.85))
						draw_line(center - Vector2(0, 10), center + Vector2(0, 6), Color(0.1, 0.15, 0.12), 2.0)
						draw_line(center - Vector2(6, -2), center + Vector2(6, -2), Color(0.1, 0.15, 0.12), 2.0)
					3:
						# Volcanic Obsidian Crag & Lava Vein
						draw_circle(center, hex_size * 0.38, Color(0.12, 0.1, 0.12, 0.95))
						draw_circle(center + Vector2(-3, -3), hex_size * 0.22, Color(0.22, 0.18, 0.2, 0.95))
						var lava_pulse = sin(anim_timer * 4.0) * 0.25 + 0.75
						draw_line(center - Vector2(10, 4), center + Vector2(4, 0), Color(1.0, 0.4, 0.05, lava_pulse), 2.5)
						draw_line(center + Vector2(4, 0), center + Vector2(10, 10), Color(1.0, 0.75, 0.1, lava_pulse), 2.0)
					_:
						# Forest Ancient Tree Stump
						draw_circle(center, hex_size * 0.38, Color(0.38, 0.26, 0.14, 0.95))
						draw_circle(center + Vector2(-2, -2), hex_size * 0.25, Color(0.55, 0.4, 0.22, 0.95))
						draw_arc(center, hex_size * 0.18, 0.0, TAU, 16, Color(0.32, 0.2, 0.1, 0.8), 1.5)
						# Green moss clump
						draw_circle(center + Vector2(-12, 6), 6.0, Color(0.25, 0.55, 0.2, 0.85))
				
	# 2. Draw Target Highlights
	if arena.pending_spell_id != "":
		var sdata = SpellData.get_spell(arena.pending_spell_id)
		var is_enemy_target = (sdata.get("type", "") == "target_enemy")
		for s in arena.all_stacks:
			if s.is_alive():
				if (is_enemy_target and s.team == 1) or (!is_enemy_target and s.team == 0):
					var s_center = HexGrid.hex_to_pixel(s.hex.x, s.hex.y, hex_size, origin)
					var ring_col = Color(1.0, 0.3, 0.1, 0.9) if is_enemy_target else Color(0.3, 1.0, 0.4, 0.9)
					draw_arc(s_center, hex_size * 0.85, 0.0, TAU, 32, ring_col, 4.0)
					draw_circle(s_center, 6.0, ring_col)
	else:
		for target in arena.attackable_targets:
			var center = HexGrid.hex_to_pixel(target.hex.x, target.hex.y, hex_size, origin)
			var points = HexGrid.get_hex_points(center, hex_size - 3.0)
			draw_colored_polygon(points, arena.COLOR_ATTACK_TARGET)
			draw_polyline(points, Color(1.0, 0.2, 0.1, 0.9), 3.0, true)
		
	# 3. Draw Living Stacks with Animated Sprites, Badges, and HP Bars
	for stack in arena.all_stacks:
		if not stack.is_alive():
			continue
			
		var center = HexGrid.hex_to_pixel(stack.hex.x, stack.hex.y, hex_size, origin)
		if stack_offsets.has(stack):
			center += stack_offsets[stack]
			
		# Shadow under unit
		draw_circle(center + Vector2(0, hex_size * 0.45), hex_size * 0.42, Color(0.0, 0.0, 0.0, 0.35))
		
		# Procedural living idle animation
		var idle_t = anim_timer + float(stack.get_instance_id() % 100) * 0.23
		var sx = 1.0
		var sy = 1.0
		var tilt = 0.0
		var bob_y = 0.0
		
		match stack.unit_id:
			"griffin":
				# Majestic wing hover and altitude bob
				bob_y = sin(idle_t * 2.8) * 5.5
				sy = 1.0 + sin(idle_t * 3.8) * 0.06
				sx = 1.0 - sin(idle_t * 3.8) * 0.03
			"fairy_archer":
				# Gentle fairy floating & wing flutter
				bob_y = sin(idle_t * 3.6) * 4.0
				sx = 1.0 + sin(idle_t * 11.0) * 0.05
				tilt = sin(idle_t * 2.4) * 0.04
			"wolf":
				# Panting breathing and forward crouch
				sy = 1.0 + sin(idle_t * 4.4) * 0.05
				sx = 1.0 + sin(idle_t * 4.4 + 0.5) * 0.03
				bob_y = absf(sin(idle_t * 4.4)) * 2.2
			"goblin":
				# Fidgety posture & spear twitch
				tilt = sin(idle_t * 3.4) * 0.06
				bob_y = absf(sin(idle_t * 3.4)) * 3.0
			"treant":
				# Heavy ancient tree trunk sway
				tilt = sin(idle_t * 1.5) * 0.04
				sy = 1.0 + sin(idle_t * 1.5) * 0.03
			_:
				bob_y = sin(idle_t * 2.5) * 2.5
				sy = 1.0 + sin(idle_t * 2.5) * 0.03
				
		# Hit flinch reaction
		if stack_flashes.has(stack):
			var fl_t = stack_flashes[stack] / 0.28
			sy *= (1.0 - fl_t * 0.2)
			sx *= (1.0 + fl_t * 0.2)
			tilt += (0.12 if stack.team == 0 else -0.12) * fl_t
			
		# Directional Facing: Team 0 faces RIGHT (towards enemies), Team 1 faces LEFT (towards player)
		var natural_faces_left = stack.data.get("natural_faces_left", (stack.unit_id in ["goblin", "wolf", "treant", "swamp_zombie", "lich"]))
		if stack.team == 0:
			if natural_faces_left:
				sx = -sx
		else:
			if not natural_faces_left:
				sx = -sx
			
		# Unit Sprite
		var target_h: float = hex_size * 2.2
		var sprite_path = stack.data.get("sprite_path", "")
		if sprite_path != "":
			if not sprite_cache.has(sprite_path):
				if ResourceLoader.exists(sprite_path):
					sprite_cache[sprite_path] = load(sprite_path)
			var tex: Texture2D = sprite_cache.get(sprite_path, null)
			if tex:
				var target_w: float = target_h * (float(tex.get_width()) / float(tex.get_height()))
				
				# Hit flash modulation
				var mod_color = Color(1, 1, 1)
				if stack_flashes.has(stack):
					var flash_t = stack_flashes[stack] / 0.28
					mod_color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.2, 0.2), flash_t)
					
				# Draw transformed sprite
				var spr_pivot = center + Vector2(0, hex_size * 0.45 + bob_y)
				draw_set_transform(spr_pivot, tilt, Vector2(sx, sy))
				var local_rect = Rect2(-target_w / 2.0, -target_h, target_w, target_h)
				draw_texture_rect(tex, local_rect, false, mod_color)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
				
		# Stack Count Badge (Bottom golden plague)
		var badge_pos = center + Vector2(0, hex_size * 0.4)
		_draw_stack_badge(badge_pos, str(stack.count), stack.team)
		
		# Health Bar (Top of unit)
		var hp_bar_pos = center + Vector2(0, -target_h + hex_size * 0.45 - 8.0 + bob_y)
		_draw_hp_bar(hp_bar_pos, stack.current_hp, stack.data.get("max_hp", 20))

		# Status pips (active buffs/debuffs at a glance)
		_draw_status_pips(center + Vector2(0, hp_bar_pos.y - 16.0), stack)
		
	# 4. Hover Forecast & Broken Arrow Indicator
	if arena.hovered_target != null and arena.hovered_target.is_alive():
		var tgt_c = HexGrid.hex_to_pixel(arena.hovered_target.hex.x, arena.hovered_target.hex.y, hex_size, origin)
		var tgt_h: float = hex_size * 2.2
		
		# If Broken Arrow applies
		if arena.hovered_is_broken:
			var arr_pos = tgt_c + Vector2(0, -tgt_h + hex_size * 0.45 - 34.0)
			_draw_broken_arrow(arr_pos)
			
		# Floating Forecast Tooltip
		if arena.hovered_forecast.size() > 0:
			var tip_pos = tgt_c + Vector2(0, -tgt_h + hex_size * 0.45 - (54.0 if arena.hovered_is_broken else 34.0))
			_draw_forecast_box(tip_pos, arena.hovered_forecast)

	# 5. Draw Flying Projectiles (Arrows & Spells)
	for p in projectiles:
		var cur_pos = p.start_pos.lerp(p.end_pos, p.progress)
		if p.type == "arrow":
			var dir = (p.end_pos - p.start_pos).normalized()
			var tail = cur_pos - dir * 28.0
			draw_line(tail, cur_pos, Color(0.85, 0.65, 0.35), 3.0)
			draw_line(cur_pos - dir * 8.0, cur_pos, Color(0.95, 0.95, 1.0), 4.5)
			draw_circle(tail, 4.0, Color(0.4, 0.9, 0.4, 0.7))
			draw_circle(cur_pos, 5.0, Color(1.0, 0.9, 0.4, 0.9))
		elif p.type == "fireball":
			draw_circle(cur_pos, 16.0, Color(1.0, 0.35, 0.05, 0.85))
			draw_circle(cur_pos, 10.0, Color(1.0, 0.85, 0.2, 0.95))
			draw_circle(cur_pos, 5.0, Color(1.0, 1.0, 0.9, 1.0))
		
	# 6. Floating Combat Numbers
	for item in arena.floating_texts:
		var c = item.color
		c.a = item.alpha
		var txt = item.text
		# draw_string с CENTER не центрирует при width = -1 (PR #3) — центрируем вручную
		var txt_size: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
		var base: Vector2 = item.pos - Vector2(txt_size.x / 2.0, 0.0)
		# High-contrast 4-way drop shadow for crisp arcade readability
		for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(2, 2)]:
			draw_string(font, base + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, c.a * 0.9))
		draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, c)

	# 7. Draw Special Effects (Lightning, Frost, Holy Halo, Stoneskin, Blind)
	for fx in special_effects:
		var ratio = clampf(fx.time / fx.max_time, 0.0, 1.0)
		var p = fx.pos
		match fx.type:
			"lightning":
				var bolt_alpha = ratio
				var segs = 7
				var cur_p = Vector2(p.x, 0)
				for i in range(segs):
					var next_y = (float(i + 1) / float(segs)) * p.y
					var next_x = p.x if i == segs - 1 else (p.x + randf_range(-30, 30))
					var next_p = Vector2(next_x, next_y)
					draw_line(cur_p, next_p, Color(0.85, 0.95, 1.0, bolt_alpha), 5.0)
					draw_line(cur_p, next_p, Color(1.0, 1.0, 1.0, bolt_alpha), 2.5)
					cur_p = next_p
				draw_circle(p, 26.0 * (1.0 - ratio), Color(0.7, 0.9, 1.0, bolt_alpha * 0.7))
				draw_circle(p, 14.0 * (1.0 - ratio), Color(1.0, 1.0, 1.0, bolt_alpha))
			"frost":
				var r_size = 38.0 * (1.0 - ratio * 0.5)
				draw_arc(p, r_size, 0, TAU, 16, Color(0.4, 0.85, 1.0, ratio * 0.9), 3.0)
				for angle_i in range(6):
					var a = (float(angle_i) / 6.0) * TAU
					var p1 = p + Vector2(cos(a), sin(a)) * (r_size * 0.3)
					var p2 = p + Vector2(cos(a), sin(a)) * r_size
					draw_line(p1, p2, Color(0.7, 0.95, 1.0, ratio), 2.0)
			"halo":
				var col = fx.get("color", Color(1.0, 0.9, 0.3))
				col.a = ratio * 0.85
				var up_y = (1.0 - ratio) * 45.0
				var halo_p = p + Vector2(0, -up_y)
				draw_arc(halo_p, 28.0 * (0.6 + 0.4 * (1.0 - ratio)), 0, TAU, 24, col, 3.5)
				draw_circle(halo_p, 12.0 * ratio, Color(col.r, col.g, col.b, ratio * 0.5))
			"stoneskin":
				var s_rad = 36.0 * (0.8 + 0.2 * (1.0 - ratio))
				draw_arc(p, s_rad, 0, TAU, 6, Color(0.65, 0.55, 0.35, ratio * 0.95), 3.5)
				draw_arc(p, s_rad * 0.7, 0, TAU, 6, Color(0.85, 0.75, 0.5, ratio * 0.8), 2.0)
			"blind":
				var b_rad = 42.0 * (1.0 - ratio * 0.4)
				draw_circle(p, b_rad, Color(1.0, 0.95, 0.4, ratio * 0.6))
				for ai in range(8):
					var ang = float(ai) * TAU / 8.0 + (1.0 - ratio) * 1.5
					var p_ray = p + Vector2(cos(ang), sin(ang)) * (b_rad * 1.4)
					draw_line(p, p_ray, Color(1.0, 1.0, 0.8, ratio), 2.5)

## Ряд цветных пипсов над стеком: активные баффы/дебаффы с одного взгляда.
func _draw_status_pips(pos: Vector2, stack: BattleStack) -> void:
	var pips: Array[Color] = []
	if stack.buff_bless_turns > 0:
		pips.append(Color(1.0, 0.85, 0.25))
	if stack.buff_haste_turns > 0:
		pips.append(Color(0.35, 0.9, 1.0))
	if stack.buff_slow_turns > 0:
		pips.append(Color(0.25, 0.4, 1.0))
	if stack.buff_stoneskin_turns > 0:
		pips.append(Color(0.66, 0.6, 0.45))
	if stack.shield_hp > 0 or stack.buff_shield_turns > 0:
		pips.append(Color(0.95, 0.97, 1.0))
	if stack.buff_retribution_turns > 0:
		pips.append(Color(1.0, 0.6, 0.2))
	if stack.buff_inspiration_turns > 0:
		pips.append(Color(0.5, 1.0, 0.5))
	if stack.is_defending:
		pips.append(Color(0.6, 0.7, 0.9))
	if stack.debuff_blind_turns > 0:
		pips.append(Color(1.0, 0.95, 0.4))
	if stack.debuff_disease_turns > 0:
		pips.append(Color(0.55, 0.7, 0.2))
	if stack.debuff_entangle_turns > 0:
		pips.append(Color(0.55, 0.35, 0.15))
	if pips.is_empty():
		return
	var n := pips.size()
	var spacing := 11.0
	var start_x := pos.x - (n - 1) * spacing * 0.5
	for i in range(n):
		var p := Vector2(start_x + i * spacing, pos.y)
		draw_circle(p + Vector2(1, 1), 4.0, Color(0, 0, 0, 0.7))
		draw_circle(p, 4.0, pips[i])
		draw_arc(p, 4.0, 0, TAU, 12, Color(0.1, 0.08, 0.04, 0.8), 1.0)

func _draw_hp_bar(pos: Vector2, cur_hp: int, max_hp: int) -> void:
	var hp_ratio = clampf(float(cur_hp) / float(max_hp), 0.0, 1.0)
	var hp_bar_w = 58.0
	var hp_bar_h = 8.0
	var rect = Rect2(pos.x - hp_bar_w / 2.0, pos.y - hp_bar_h / 2.0, hp_bar_w, hp_bar_h)
	
	# Background
	draw_rect(rect, Color(0.1, 0.1, 0.1, 0.9), true)
	# Fill
	var fill_col = Color(0.2, 0.85, 0.3) if hp_ratio > 0.5 else (Color(0.9, 0.75, 0.2) if hp_ratio > 0.25 else Color(0.95, 0.2, 0.2))
	var fill_w = maxf(1.0, (hp_bar_w - 2.0) * hp_ratio)
	draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(fill_w, hp_bar_h - 2.0)), fill_col, true)
	# Gold border
	draw_rect(rect, Color(0.85, 0.75, 0.35, 0.95), false, 1.2)
	
	# HP text
	var font = ThemeDB.fallback_font
	var hp_str = "%d/%d" % [cur_hp, max_hp]
	draw_string(font, pos + Vector2(0, -6), hp_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 0.95))

func _draw_stack_badge(pos: Vector2, text: String, team: int) -> void:
	var badge_w = 64.0
	var badge_h = 28.0
	var rect = Rect2(pos.x - badge_w / 2.0, pos.y - badge_h / 2.0, badge_w, badge_h)
	
	var bg_col = Color(0.12, 0.3, 0.65, 0.92) if team == 0 else Color(0.65, 0.15, 0.15, 0.92)
	draw_rect(rect, bg_col, true)
	draw_rect(rect, Color(0.95, 0.82, 0.35, 0.95), false, 2.0)
	
	var font = ThemeDB.fallback_font
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	var text_pos = pos + Vector2(-text_size.x / 2.0, text_size.y / 3.0)
	draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.9))
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 0.95))

func _draw_broken_arrow(pos: Vector2) -> void:
	var red = Color(1.0, 0.25, 0.15)
	draw_line(pos + Vector2(-16, 4), pos + Vector2(-2, -3), red, 3.0)
	draw_line(pos + Vector2(2, -1), pos + Vector2(16, 7), red, 3.0)
	draw_line(pos + Vector2(16, 7), pos + Vector2(10, 8), red, 3.0)
	draw_line(pos + Vector2(16, 7), pos + Vector2(13, 2), red, 3.0)
	draw_circle(pos, 3.0, Color(1.0, 0.9, 0.2))
	
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(0, -6), "ШТРАФ 50%", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.3, 0.2))

func _draw_forecast_box(pos: Vector2, forecast: Dictionary) -> void:
	var font = ThemeDB.fallback_font
	var txt = "Урон: %d-%d (Потери: %d-%d)" % [
		forecast.min_dmg, forecast.max_dmg, forecast.min_cas, forecast.max_cas
	]
	var sz = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	var box_w = sz.x + 16.0
	var box_h = 22.0
	var r = Rect2(pos.x - box_w / 2.0, pos.y - box_h / 2.0, box_w, box_h)
	
	draw_rect(r, Color(0.12, 0.08, 0.04, 0.92), true)
	draw_rect(r, Color(0.95, 0.82, 0.35, 0.9), false, 1.5)
	draw_string(font, pos + Vector2(0, 4), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(1, 0.95, 0.75))
