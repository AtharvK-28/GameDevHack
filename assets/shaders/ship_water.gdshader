// Mobile fallback: opaque waves and painted foam, without screen/depth dependencies.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 water_colour : source_color = vec4(0.125, 0.247, 0.38, 1.0);
uniform float wave_height = 0.12;
uniform float wave_speed = 0.65;
uniform bool near_water = true;
varying vec3 sea_position;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fade = near_water ? 1.0 - smoothstep(22.0, 30.0, max(abs(VERTEX.x), abs(VERTEX.z))) : 0.0;
	VERTEX.y += (sin(world.x * 0.7 + TIME * wave_speed) + cos(world.z * 0.9 + TIME * wave_speed)) * wave_height * fade;
	sea_position = world;
}
void fragment() {
	vec2 p = sea_position.xz;
	float ripples = sin(p.x * 2.0 + TIME) * cos(p.y * 2.8 + TIME * 0.6);
	float hull_distance = min(abs(p.y + 0.25), abs(p.y - 10.25));
	float hull_foam = (1.0 - smoothstep(0.1, 0.65, hull_distance)) * step(0.0, p.x) * step(p.x, 26.0);
	float tug_foam = (1.0 - smoothstep(0.1, 0.45, min(abs(p.y - 13.4), abs(p.y - 18.8)))) * step(10.0, p.x) * step(p.x, 18.0);
	float foam = max(hull_foam, tug_foam) * (0.18 + 0.12 * ripples);
	ALBEDO = water_colour.rgb * (0.94 + ripples * 0.025) + vec3(0.4, 0.48, 0.56) * foam;
	ROUGHNESS = 0.8;
	NORMAL_MAP = vec3(0.5 + sin(p.x * 1.5 + TIME) * 0.04, 0.5 + cos(p.y * 1.4 + TIME) * 0.04, 1.0);
}
