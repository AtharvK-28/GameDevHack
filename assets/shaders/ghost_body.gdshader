shader_type spatial;
// Ghost body: see-through blue core, glowing cyan rim, drifting shimmer and a tail that fades out.
// UV.y runs from the tail tip (0) to the top of the head (1).
render_mode blend_mix, depth_draw_always, cull_back, specular_disabled, shadows_disabled;

uniform vec4 core_colour : source_color = vec4(0.35, 0.68, 1.0, 1.0);
uniform vec4 rim_colour : source_color = vec4(0.72, 0.96, 1.0, 1.0);
// Base opacity of the body. GhostModel animates this between 0.25 and 0.45.
uniform float opacity : hint_range(0.0, 1.0) = 0.35;
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float rim_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float glow_energy : hint_range(0.0, 8.0) = 1.4;
uniform float rim_glow : hint_range(0.0, 8.0) = 2.4;
// Portion of the height, from the tail tip up, that fades to nothing.
uniform float tail_fade : hint_range(0.01, 1.0) = 0.32;
uniform float swirl_speed = 1.6;
uniform float swirl_amount : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float swirl = 0.5 + 0.5 * sin(UV.y * 22.0 - TIME * swirl_speed + sin(UV.x * 9.0 + TIME * 0.7) * 1.5);
	float fade = smoothstep(0.0, tail_fade, UV.y);
	vec3 colour = mix(core_colour.rgb, rim_colour.rgb, rim);
	ALBEDO = colour * 0.25;
	EMISSION = colour * (glow_energy + rim * rim_glow) * (1.0 - swirl_amount + swirl_amount * swirl);
	ALPHA = clamp((opacity + rim * rim_opacity) * fade, 0.0, 1.0);
}
