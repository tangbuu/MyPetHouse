shader_type canvas_item;

uniform float rain_speed    : hint_range(0.1, 5.0) = 1.8;
uniform float rain_density  : hint_range(0.0, 1.0) = 0.55;
uniform float rain_opacity  : hint_range(0.0, 0.6) = 0.13;
uniform float rain_angle    : hint_range(-0.4, 0.4) = 0.07;
uniform float streak_length : hint_range(0.01, 0.25) = 0.10;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float drop_layer(vec2 uv, float cols, float seed, float speed_mult) {
	// Diagonal shear
	uv.x += uv.y * rain_angle;

	float col_id  = floor(uv.x * cols) + seed * 31.7;
	float rnd     = hash(vec2(col_id, seed));
	if (rnd > rain_density) return 0.0;

	float speed   = speed_mult * (0.5 + rnd * 0.8);
	float phase   = hash(vec2(col_id, seed + 1.0));
	float drop_y  = fract(TIME * rain_speed * speed + phase);

	// dy > 0 means pixel is above the drop head → inside streak
	float dy = drop_y - uv.y;
	if (dy < -0.5) dy += 1.0;

	float in_streak  = step(0.0, dy) * step(dy, streak_length);
	float brightness = in_streak * (1.0 - dy / streak_length);

	// Thin the drop horizontally
	float local_x = fract(uv.x * cols);
	float x_mask  = 1.0 - smoothstep(0.05, 0.45, abs(local_x - 0.5) * 2.0);

	return brightness * x_mask;
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Three parallax layers: near (fast), mid, far (slow)
	float rain  = drop_layer(uv,        80.0, 0.0, 1.00) * 1.00;
	rain       += drop_layer(uv * 0.75, 60.0, 5.0, 0.70) * 0.55;
	rain       += drop_layer(uv * 0.55, 45.0, 9.0, 0.50) * 0.30;

	rain = clamp(rain, 0.0, 1.0);
	// Slightly blue-white rain color
	COLOR = vec4(0.78, 0.90, 1.0, rain * rain_opacity);
}
