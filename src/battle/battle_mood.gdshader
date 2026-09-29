shader_type canvas_item;

// Настроение фона боя: цветокоррекция, небо и туман сверху/снизу, дымка, жар, виньетка.
// Параметры задаёт BattleMood.MOODS; значения по умолчанию оставляют картинку как есть.

uniform vec3 tint = vec3(1.0);
uniform float saturation = 1.0;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform vec4 sky_color = vec4(0.0);  // заливка неба, a — сила (к верхнему краю)
uniform vec4 fog_color = vec4(0.0);  // туман/марево от нижнего края, a — сила
uniform float fog_start = 0.55;      // UV.y, где начинается туман
uniform float mist_speed = 0.0;      // скорость дрейфа клочьев тумана; 0 — неподвижно
uniform float heat_haze = 0.0;       // амплитуда дрожания воздуха над землёй
uniform float vignette = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	if (heat_haze > 0.0) {
		uv.x += sin(uv.y * 48.0 + TIME * 3.0) * heat_haze * smoothstep(0.35, 1.0, uv.y);
	}
	vec4 src = texture(TEXTURE, uv);
	vec3 col = src.rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col *= tint * brightness;
	col = mix(col, sky_color.rgb, sky_color.a * (1.0 - smoothstep(0.0, 0.45, UV.y)));
	float fog = smoothstep(fog_start, 1.0, UV.y);
	if (mist_speed > 0.0) {
		float n = value_noise(vec2(UV.x * 5.0 + TIME * mist_speed, UV.y * 9.0 - TIME * mist_speed * 0.5));
		fog = clamp(fog * (0.55 + 0.9 * n), 0.0, 1.0);
	}
	col = mix(col, fog_color.rgb, fog_color.a * fog);
	col *= 1.0 - vignette * smoothstep(0.35, 0.85, distance(UV, vec2(0.5)));
	COLOR = vec4(col, src.a);
}
