class_name BattleMood
extends RefCounted

## Настроение поля боя. Фон у всех глав один (солнечный луг с замком), поэтому
## Проклятые Топи и Пик Дракона передаются цветокоррекцией, туманом/жаром и частицами;
## глава 1 остаётся как есть. Когда появятся свои фоны глав — достаточно менять
## текстуру фона в apply() (шейдер можно оставить для атмосферы или убрать).

const SHADER := preload("res://src/battle/battle_mood.gdshader")

const MOODS := {
	"swamp": {
		"tint": Vector3(0.8, 0.96, 0.9), "saturation": 0.45, "brightness": 0.74, "contrast": 0.95,
		"sky_color": Color(0.33, 0.4, 0.38, 0.55), "fog_color": Color(0.56, 0.66, 0.6, 0.5),
		"fog_start": 0.42, "mist_speed": 0.05, "heat_haze": 0.0, "vignette": 0.45,
		"particles": "wisps",
	},
	"volcano": {
		"tint": Vector3(1.2, 0.74, 0.54), "saturation": 0.8, "brightness": 0.8, "contrast": 1.1,
		"sky_color": Color(0.42, 0.1, 0.05, 0.6), "fog_color": Color(0.38, 0.1, 0.04, 0.3),
		"fog_start": 0.6, "mist_speed": 0.0, "heat_haze": 0.0022, "vignette": 0.55,
		"particles": "embers",
	},
}

const SWAMP_UNITS := ["skeleton_archer", "swamp_zombie", "lich"]

## В кампании настроение задаёт глава, на Арене — состав врага (дракон — вулкан, нежить — топи).
static func mood_for(chapter: int, is_demo: bool, enemy_ids: Array) -> String:
	if is_demo:
		if enemy_ids.has("red_dragon"):
			return "volcano"
		for uid in enemy_ids:
			if SWAMP_UNITS.has(uid):
				return "swamp"
		return ""
	match chapter:
		2:
			return "swamp"
		3:
			return "volcano"
	return ""

## Настроение текущего боя по его отрядам (на Арене — по составу врага).
static func apply_for_battle(bg: TextureRect, stacks: Array) -> void:
	var enemy_ids := []
	for s in stacks:
		if s.team == 1:
			enemy_ids.append(s.unit_id)
	apply(bg, mood_for(GameState.current_chapter, GameState.is_demo_battle, enemy_ids))

## Шейдер на фон и частицы поверх него (под сеткой и отрядами).
## При «Упрощённых анимациях» — только неподвижная цветокоррекция.
static func apply(bg: TextureRect, mood: String) -> void:
	if not MOODS.has(mood):
		return
	var m: Dictionary = MOODS[mood]
	var calm: bool = SettingsManager.reduced_animations
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	for key in ["tint", "saturation", "brightness", "contrast", "sky_color", "fog_color", "fog_start", "vignette"]:
		mat.set_shader_parameter(key, m[key])
	mat.set_shader_parameter("mist_speed", 0.0 if calm else m["mist_speed"])
	mat.set_shader_parameter("heat_haze", 0.0 if calm else m["heat_haze"])
	bg.material = mat
	if not calm:
		bg.add_child(_make_particles(str(m["particles"])))

static func _make_particles(kind: String) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "MoodParticles"
	p.texture = _soft_dot()
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = glow
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var ramp := Gradient.new()
	match kind:
		"embers":
			# Искры поднимаются от раскалённой земли и гаснут в воздухе
			p.amount = 90
			p.lifetime = 5.0
			p.position = Vector2(960, 900)
			p.emission_rect_extents = Vector2(1000, 220)
			p.direction = Vector2(0.15, -1.0)
			p.spread = 25.0
			p.gravity = Vector2(0, -8)
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 110.0
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.85
			ramp.set_color(0, Color(1.0, 0.85, 0.4, 0.0))
			ramp.add_point(0.15, Color(1.0, 0.8, 0.35, 1.0))
			ramp.add_point(0.6, Color(1.0, 0.45, 0.1, 0.8))
			ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 0.15, 0.05, 0.0))
		_:
			# Болотные огоньки медленно плывут над топью
			p.amount = 30
			p.lifetime = 7.0
			p.position = Vector2(960, 720)
			p.emission_rect_extents = Vector2(1000, 320)
			p.direction = Vector2(1.0, -0.2)
			p.spread = 180.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 22.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
			ramp.set_color(0, Color(0.6, 1.0, 0.8, 0.0))
			ramp.add_point(0.5, Color(0.7, 1.0, 0.85, 0.9))
			ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 1.0, 0.8, 0.0))
	p.color_ramp = ramp
	p.preprocess = p.lifetime # в начале боя частицы уже в воздухе
	return p

## Мягкая круглая точка 16×16 для частиц — без отдельного файла текстуры.
static func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
