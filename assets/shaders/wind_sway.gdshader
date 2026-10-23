// Wind sway for grass, weeds and trees: each vertex moves by its height above the model's base, so trunks stay
// planted. The phase comes from world position, so every MultiMesh copy sways on its own. Colour is a plain
// albedo (optionally times a texture), matching the muted Kenney materials it replaces.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;
uniform float sway_strength = 0.05; // Metres of movement per metre of height.
uniform float sway_speed = 1.3; // Radians per second.

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float height = max(VERTEX.y, 0.0);
	float phase = world.x * 0.31 + world.z * 0.17;
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_strength * height;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + phase) * sway_strength * 0.5 * height;
}

void fragment() {
	vec4 colour = albedo;
	if (use_texture) {
		colour *= texture(albedo_texture, UV);
	}
	ALBEDO = colour.rgb;
	ROUGHNESS = 0.95;
}
