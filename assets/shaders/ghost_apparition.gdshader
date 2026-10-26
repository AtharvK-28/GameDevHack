shader_type spatial;
// A see-through apparition that keeps its own colours: the captain still reads as himself, while a
// ghost-green fresnel edge says he is the ghost. Opacity is animated from GDScript so he shimmers
// like the bedsheet wisp does. Depth is written so his overlapping parts never show through.
render_mode blend_mix, depth_draw_always, cull_back, specular_disabled, shadows_disabled;

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
// Multiplies the texture, so an untextured part can carry its own flat colour.
uniform vec4 base_colour : source_color = vec4(1.0);
// How far the model's own colours are pulled toward ghost green: 0 keeps them, 1 replaces them.
uniform vec4 tint : source_color = vec4(0.45, 1.0, 0.72, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.3;
// Base opacity. GhostCaptainModel animates it.
uniform float opacity : hint_range(0.0, 1.0) = 0.7;
uniform vec4 rim_colour : source_color = vec4(0.55, 1.0, 0.78, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.5;
uniform float rim_opacity : hint_range(0.0, 1.0) = 0.5;
uniform float rim_glow : hint_range(0.0, 8.0) = 0.8;
// His own colours glow faintly of themselves, so he reads in the dark without the rim washing him out.
uniform float self_glow : hint_range(0.0, 2.0) = 0.45;

void fragment() {
	vec4 texel = texture(albedo_texture, UV) * base_colour;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	ALBEDO = mix(texel.rgb, tint.rgb, tint_amount);
	EMISSION = ALBEDO * self_glow + rim_colour.rgb * rim * rim_glow;
	ALPHA = clamp(texel.a * (opacity + rim * rim_opacity), 0.0, 1.0);
}
