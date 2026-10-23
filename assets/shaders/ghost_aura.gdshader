shader_type spatial;
// Soft glow halo on the ghost's inflated aura shell. Additive, so it glows even without
// WorldEnvironment bloom. Brightest just outside the body's outline and zero over the face.
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow_colour : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 0.9;
uniform float tail_fade : hint_range(0.01, 1.0) = 0.4;
uniform float pulse_speed = 0.8;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float halo = 4.0 * facing * (1.0 - facing);
	halo *= halo;
	float fade = smoothstep(0.0, tail_fade, UV.y);
	float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * TAU * pulse_speed));
	ALBEDO = glow_colour.rgb;
	ALPHA = clamp(halo * fade * pulse * intensity, 0.0, 1.0);
}
