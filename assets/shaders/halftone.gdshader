// Comic halftone backdrop: a flat tint with a grid of dots that grow toward the bottom of the screen.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.1, 0.07, 0.16, 0.72);
uniform vec4 dot_colour : source_color = vec4(1.0, 1.0, 1.0, 0.12);
uniform float spacing = 14.0; // Pixels between dot centres.

void fragment() {
	vec2 pixel = FRAGCOORD.xy;
	vec2 cell = fract(pixel / spacing) - 0.5;
	float grow = clamp(SCREEN_UV.y, 0.0, 1.0); // Dots fill out toward the bottom.
	float radius = mix(0.08, 0.38, grow);
	float dot_mask = 1.0 - smoothstep(radius - 0.05, radius + 0.05, length(cell));
	COLOR = vec4(mix(tint.rgb, dot_colour.rgb, dot_mask * dot_colour.a), tint.a);
}
