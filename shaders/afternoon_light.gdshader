shader_type canvas_item;

uniform float intensity    : hint_range(0.0, 1.0) = 0.0;
uniform vec2  window_uv    = vec2(0.5, 0.35);
uniform float beam_width   : hint_range(0.01, 0.3) = 0.065;
uniform float beam_shear   : hint_range(-2.0, 2.0) = -1.0;
uniform float beam_reach   : hint_range(0.1, 1.0)  = 0.45;
// 0 = afternoon (13h), 0.5 = golden hour (16-17h), 1 = sunset (18-19h)
uniform float time_of_day  : hint_range(0.0, 1.0)  = 0.5;

float hash2(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i),                  hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// ── 3-phase color: Afternoon → Golden Hour → Sunset ───────────────────────
	// Phase 0.0–0.4: afternoon — warm yellow
	// Phase 0.4–0.7: golden hour — deep amber orange
	// Phase 0.7–1.0: sunset — orange red
	vec3 c_afternoon   = vec3(1.00, 0.84, 0.46);
	vec3 c_golden_hour = vec3(1.00, 0.58, 0.24);
	vec3 c_sunset      = vec3(1.00, 0.42, 0.15);
	vec3 warm_tint;
	if (time_of_day < 0.4) {
		warm_tint = mix(c_afternoon,   c_golden_hour, time_of_day / 0.4);
	} else if (time_of_day < 0.7) {
		warm_tint = mix(c_golden_hour, c_sunset,      (time_of_day - 0.4) / 0.3);
	} else {
		warm_tint = mix(c_sunset,      vec3(1.00, 0.40, 0.14), (time_of_day - 0.7) / 0.3);
	}

	// ── Shear: nonlinear — sun drops fast toward end of day ──────────────────
	// pow curve makes the last hour feel dramatic
	float e           = pow(time_of_day, 1.6);
	float shear_scale = mix(0.7, 2.0, e);
	float actual_shear = beam_shear * shear_scale;

	// ── Gradient global tint — fades from window outward ─────────────────────
	float dist      = distance(uv, window_uv);
	float local_w   = 1.0 - smoothstep(0.0, 0.9, dist);
	// min = 0.06: room-wide warm bounce even away from window
	float global_warm = intensity * mix(0.06, 0.16, local_w);

	// ── Sky gradient: orange near horizon, fades upward ───────────────────────
	// horizon band (~uv.y 0.3–0.6) gets orange push; above that stays neutral
	float horizon_band = smoothstep(0.0, 0.35, uv.y) * (1.0 - smoothstep(0.35, 0.65, uv.y));
	float sky_top      = 1.0 - smoothstep(0.0, 0.4, uv.y);
	float sky_haze     = (horizon_band * 0.12 + sky_top * 0.04) * intensity;
	global_warm       += sky_haze;

	// ── Beam shape ────────────────────────────────────────────────────────────
	vec2 d = uv - window_uv;

	float edge_noise = (vnoise(uv * 18.0 + TIME * 0.2) - 0.5) * 0.006;
	float jitter     = sin(d.y * 50.0 + TIME * 2.0) * 0.002;
	float sheared    = d.x - actual_shear * d.y + edge_noise + jitter;

	float in_width = smoothstep(beam_width, beam_width * 0.4, abs(sheared));
	float in_reach = smoothstep(0.0, 0.03, d.y) * smoothstep(beam_reach, beam_reach * 0.6, d.y);
	float fade     = 1.0 - smoothstep(0.0, beam_reach, d.y);
	float fade_exp = pow(fade, 1.5);

	// Beam: very thin, very faint — just a hint of the light ray
	float beam_soft = in_width           * in_reach * fade_exp * 0.06;
	float beam_core = pow(in_width, 4.0) * in_reach * fade_exp * 0.14;
	float beam      = (beam_soft + beam_core) * intensity;

	// Faint dust along beam edges only
	vec2 dust_uv = uv * 12.0;
	dust_uv += vec2(
		sin(dust_uv.y * 3.0 + TIME * 0.8) * 0.02,
		cos(dust_uv.x * 2.0 + TIME * 0.6) * 0.02);
	dust_uv.y += TIME * 0.015;
	float dust      = smoothstep(0.55, 0.9, vnoise(dust_uv));
	float dust_mask = 1.0 - pow(in_width, 3.0);
	beam += dust * dust_mask * 0.04 * intensity;

	// ── Window bloom — main source glow, large and warm ──────────────────────
	float win_glow = (1.0 - smoothstep(0.0, 0.22, dist)) * intensity * 0.55;

	// ── Floor light patch — the main feature ─────────────────────────────────
	// Wide soft parallelogram where window light falls on the floor
	vec2  beam_end  = window_uv + vec2(actual_shear * beam_reach, beam_reach);
	vec2  beam_dir  = normalize(vec2(actual_shear, 1.0));
	vec2  rel       = uv - beam_end;
	float along     = dot(rel, beam_dir);
	float across    = dot(rel, vec2(-beam_dir.y, beam_dir.x));

	// Inner bright patch (window frame silhouette on floor)
	float patch_core = exp(-abs(along) * 7.0) * exp(-abs(across) * 11.0);
	// Outer soft halo (bounce/scatter around patch)
	float patch_halo = exp(-abs(along) * 3.5) * exp(-abs(across) * 5.0) * 0.4;
	float floor_patch = (patch_core + patch_halo) * intensity * 0.38;

	// Subtle animated shimmer on the patch (heat/air movement)
	float shimmer = vnoise(uv * 20.0 + TIME * 0.08) * 0.06 + 0.94;
	floor_patch  *= shimmer;

	COLOR = vec4(warm_tint, clamp(global_warm + beam + win_glow + floor_patch, 0.0, 0.65));
}
