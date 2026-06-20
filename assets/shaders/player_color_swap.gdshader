shader_type canvas_item;

// ── Source colors (sampled from the original sprite) ─────────────────────────
uniform vec4 hair_source  : source_color = vec4(0.353, 0.588, 0.824, 1.0); // #5A96D2
uniform vec4 skirt_source : source_color = vec4(0.196, 0.392, 0.706, 1.0); // #3264B4

// ── Target colors (set at runtime via CharacterColorManager) ─────────────────
uniform vec4 hair_target  : source_color = vec4(0.353, 0.588, 0.824, 1.0);
uniform vec4 skirt_target : source_color = vec4(0.196, 0.392, 0.706, 1.0);

// ── Tolerance: how far a pixel can be from the source and still be recolored ──
// 0.12 ≈ 30/255 — tight enough to separate hair from skirt, loose enough for
// anti-aliased edge pixels to get partial recoloring.
uniform float threshold : hint_range(0.0, 0.5) = 0.12;

// Euclidean distance between two RGB colors (ignores alpha)
float color_dist(vec3 a, vec3 b) {
	vec3 d = a - b;
	return sqrt(dot(d, d));
}

// Recolor a pixel: preserves the per-channel ratio relative to source so that
// highlights (#source * 1.3) and shadows (#source * 0.6) scale naturally on
// the target color — no flat tint, shading is kept intact.
vec3 recolor(vec3 pixel, vec3 source, vec3 target) {
	// Avoid div-by-zero on very dark source channels
	vec3 ratio = pixel / max(source, vec3(0.001));
	return clamp(target * ratio, vec3(0.0), vec3(1.0));
}

void fragment() {
	vec4 px  = texture(TEXTURE, UV);
	vec3 col = px.rgb;

	float d_hair  = color_dist(col, hair_source.rgb);
	float d_skirt = color_dist(col, skirt_source.rgb);

	float blend_hair  = step(d_hair,  threshold) * (1.0 - d_hair  / threshold);
	float blend_skirt = step(d_skirt, threshold) * (1.0 - d_skirt / threshold);

	col = mix(col, recolor(col, hair_source.rgb,  hair_target.rgb),  blend_hair);
	col = mix(col, recolor(col, skirt_source.rgb, skirt_target.rgb), blend_skirt);

	COLOR = vec4(col, px.a);
}
