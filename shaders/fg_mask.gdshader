shader_type canvas_item;

uniform sampler2D mask_texture : hint_default_black;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float mask = texture(mask_texture, UV).r;
	COLOR = vec4(color.rgb, color.a * mask);
}
