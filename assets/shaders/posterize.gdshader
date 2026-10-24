// Repaints a photo-scanned texture in one flat colour (STYLE.md: no photo textures). Only the photo's light and dark
// survive, in a few bands, as painted shading over the base colour, so the scan reads as a comic prop.
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float levels = 4.0; // Shading bands.
uniform vec4 paint : source_color = vec4(1.0, 0.6, 0.2, 1.0); // The base colour.
uniform float shade_low = 0.55; // The darkest band, as a share of the base colour.
uniform float shade_high = 1.1; // The lightest band.
uniform float roughness_value = 0.85;

void fragment() {
	float grey = dot(texture(albedo_texture, UV).rgb, vec3(0.299, 0.587, 0.114));
	float band = floor(clamp(grey * 1.4, 0.0, 1.0) * levels + 0.5) / levels;
	ALBEDO = clamp(paint.rgb * mix(shade_low, shade_high, band), 0.0, 1.0);
	ROUGHNESS = roughness_value;
}
