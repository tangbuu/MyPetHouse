shader_type canvas_item;

uniform vec4  overlay_color    : source_color = vec4(0.04, 0.04, 0.18, 0.65);
uniform vec2  viewport_size                   = vec2(540.0, 1170.0);
uniform float light_radius_norm               = 0.31;
uniform float light_intensity                 = 1.0;
// Isometric shear: nghiêng vùng sáng theo góc tường isometric.
// 0 = tròn thuần; ~0.45 khớp tường 2:1 isometric; âm = nghiêng ngược.
uniform float iso_shear                       = 0.45;
// Feather: kéo dài vùng fade rìa thêm n% radius để mềm đường viền.
// 0 = rìa như cũ; 0.5 = fade kéo thêm 50% radius ra ngoài.
uniform float edge_feather                    = 0.3;

uniform vec2 light_pos_0 = vec2(-9.0, -9.0);
uniform vec2 light_pos_1 = vec2(-9.0, -9.0);
uniform vec2 light_pos_2 = vec2(-9.0, -9.0);
uniform vec2 light_pos_3 = vec2(-9.0, -9.0);

// Hướng tường của từng đèn: +1 = wall_left, -1 = wall_right, 0 = không xác định.
// Set từ GDScript dựa trên grid_surface meta, không tính từ UV position.
uniform float light_dir_0 = 0.0;
uniform float light_dir_1 = 0.0;
uniform float light_dir_2 = 0.0;
uniform float light_dir_3 = 0.0;

float lamp_hole(vec2 screen_uv, vec2 lamp_uv, float wall_dir) {
	if (lamp_uv.x < -1.0) return 0.0;
	float aspect = viewport_size.y / viewport_size.x;
	vec2 raw = screen_uv - lamp_uv;

	float wall_shear = iso_shear * wall_dir;
	vec2 raw_iso = vec2(raw.x, raw.y - raw.x * wall_shear);
	vec2 d = raw_iso * vec2(1.0, aspect);
	float dist = length(d);

	// Feathered smoothstep: rìa cứng tại light_radius_norm, fade kéo thêm edge_feather ra ngoài.
	float r_hard = light_radius_norm;
	float r_soft = light_radius_norm * (1.0 + edge_feather);
	float radial = 1.0 - smoothstep(r_hard, r_soft, dist);

	// Soft downward bias — chặn ánh sáng xuyên tường phía trên.
	float dir_bias = 0.05 + 0.95 * smoothstep(-0.03, 0.15, raw.y);

	return radial * dir_bias;
}

void fragment() {
	float no_light = 1.0;
	no_light *= (1.0 - lamp_hole(SCREEN_UV, light_pos_0, light_dir_0));
	no_light *= (1.0 - lamp_hole(SCREEN_UV, light_pos_1, light_dir_1));
	no_light *= (1.0 - lamp_hole(SCREEN_UV, light_pos_2, light_dir_2));
	no_light *= (1.0 - lamp_hole(SCREEN_UV, light_pos_3, light_dir_3));
	float influence = clamp((1.0 - no_light) * light_intensity, 0.0, 1.0);

	vec3 warm_col = vec3(0.55, 0.32, 0.03);
	vec3 col      = mix(overlay_color.rgb, warm_col, influence * 0.75);
	float alpha   = mix(overlay_color.a, overlay_color.a * 0.08, influence);
	COLOR = vec4(col, alpha);
}
