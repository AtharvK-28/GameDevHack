// The code light grade (STYLE.md): over the 3D scene and under the HUD, the screen's edges sink into the night
// colour (a vignette) so the centre, where the camera keeps the action, is the brightest part of the picture.
// A second rect with the same shader in "warm" mode adds a soft warm wash at the centre.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 colour : source_color = vec4(0.07, 0.04, 0.11, 1.0);
uniform float strength = 0.3; // Opacity at the corners (vignette) or at the centre (warm wash).
uniform vec2 centre = vec2(0.5, 0.55); // Screen point the grade is centred on.
uniform float inner = 0.3; // Distance from the centre where the vignette starts / the wash ends.
uniform float outer = 0.85;
uniform bool warm = false;

void fragment() {
	vec2 offset = (SCREEN_UV - centre) * vec2(1.6, 1.0); // Wider than tall, like the screen.
	float reach = smoothstep(inner, outer, length(offset));
	float amount = warm ? (1.0 - reach) * strength : reach * strength;
	COLOR = vec4(colour.rgb, amount);
}
