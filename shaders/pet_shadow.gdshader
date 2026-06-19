shader_type canvas_item;

uniform float shadow_alpha  : hint_range(0.0, 1.0)   = 0.35;
// Hướng bóng đổ trong screen-space, đã normalize.
// Đèn bên phải → bóng đổ trái-lên: (-0.894, -0.447)
// Đèn bên trái → bóng đổ phải-xuống: (0.894, 0.447)
// Tỉ lệ y = x * 0.5 phản ánh góc nghiêng sàn Isometric 2:1
uniform vec2  light_dir                               = vec2(-0.894, -0.447);
// Độ dài bóng tính bằng pixel local (trước scale).
// UV.y=1 (chân thực thể) không dịch chuyển.
// UV.y=0 (đỉnh thực thể) dịch chuyển tối đa shadow_length * light_dir.
uniform float shadow_length : hint_range(0.0, 600.0) = 80.0;

void vertex() {
	// height_frac = 0 tại chân (UV.y=1), = 1 tại đỉnh (UV.y=0)
	// Chân bóng ghim cố định vào vị trí chân thực thể.
	float height_frac = 1.0 - UV.y;
	VERTEX.x += height_frac * shadow_length * light_dir.x;
	VERTEX.y += height_frac * shadow_length * light_dir.y;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	COLOR    = vec4(0.0, 0.0, 0.0, col.a * shadow_alpha);
}
