shader_type canvas_item;

uniform vec4  overlay_color    : source_color = vec4(0.04, 0.04, 0.18, 0.65);
uniform vec2  viewport_size                   = vec2(540.0, 1170.0);
uniform float light_radius_norm               = 0.31;

uniform vec2 light_pos_0 = vec2(-9.0, -9.0);
uniform vec2 light_pos_1 = vec2(-9.0, -9.0);
uniform vec2 light_pos_2 = vec2(-9.0, -9.0);
uniform vec2 light_pos_3 = vec2(-9.0, -9.0);

float lamp_hole(vec2 screen_uv, vec2 lamp_uv) {
	if (lamp_uv.x < -1.0) return 0.0;
	float aspect = viewport_size.y / viewport_size.x;
	vec2 d = (screen_uv - lamp_uv) * vec2(1.0, aspect);
	return 1.0 - smoothstep(0.0, light_radius_norm, length(d));
}

void fragment() {
	float no_light = 1.0;
	no_light *= (1.0 - lamp_hole(SCREEN_UV, light_pos_0));
	no_light *= (1.0 - lamp_hole(SCREEN_UV, light_pos_1));
	no_light *= (1.0 - lamp_hole(SCREEN_UV, light_pos_2));
	no_light *= (1.0 - lamp_hole(SCREEN_UV, light_pos_3));
	float influence = clamp(1.0 - no_light, 0.0, 1.0);

	vec3 warm_col = vec3(0.55, 0.32, 0.03);
	vec3 col      = mix(overlay_color.rgb, warm_col, influence * 0.75);
	float alpha   = mix(overlay_color.a, overlay_color.a * 0.08, influence);
	COLOR = vec4(col, alpha);
}
