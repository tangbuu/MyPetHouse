shader_type canvas_item;

uniform float rain_speed    : hint_range(0.1, 5.0) = 1.8;
uniform float rain_density  : hint_range(0.0, 1.0) = 0.55;
uniform float rain_opacity  : hint_range(0.0, 0.6) = 0.13;
uniform float rain_angle    : hint_range(-0.4, 0.4) = 0.18;
uniform float streak_length : hint_range(0.01, 0.25) = 0.06;

// Cheap integer-based hash — no sin()
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(p));
	uint n = q.x * 1597334673u ^ q.y * 3812015801u;
	n = (n ^ (n >> 16u)) * 0x45d9f3bu;
	return float(n) * (1.0 / float(0xffffffffu));
}

float drop_layer(vec2 uv, float cols, float seed, float speed_mult, float t) {
	uv.x += uv.y * rain_angle;

	float col_id = floor(uv.x * cols) + seed * 31.7;
	float rnd    = hash(vec2(col_id, seed));
	if (rnd > rain_density) return 0.0;

	float speed  = speed_mult * (0.5 + rnd * 0.8);
	float phase  = hash(vec2(col_id, seed + 1.0));
	float drop_y = fract(t * speed + phase);

	float dy = drop_y - uv.y;
	if (dy < -0.5) dy += 1.0;

	float in_streak  = step(0.0, dy) * step(dy, streak_length);
	float brightness = in_streak * (1.0 - dy / streak_length);

	float local_x = fract(uv.x * cols);
	float x_mask  = 1.0 - smoothstep(0.05, 0.45, abs(local_x - 0.5) * 2.0);

	return brightness * x_mask;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t  = TIME * rain_speed;

	float rain  = drop_layer(uv,        80.0, 0.0, 1.00, t);
	rain       += drop_layer(uv * 0.65, 52.0, 5.0, 0.60, t) * 0.45;

	COLOR = vec4(0.78, 0.90, 1.0, min(rain, 1.0) * rain_opacity);
}
