// Mobile fallback: opaque waves and painted foam, without screen/depth dependencies.
// A long rolling swell runs under the short ripples, with foam on the swell's tops and around the hull and tug.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 water_colour : source_color = vec4(0.125, 0.247, 0.38, 1.0);
uniform float wave_height = 0.12;
uniform float wave_speed = 0.65;
uniform float swell_height = 0.3;
uniform float swell_speed = 0.8;
uniform bool near_water = true;
// Foam where the hulls meet the water: a rounded box around each (centre x, z, then half length and width).
uniform vec4 hull_shape = vec4(16.0, 6.0, 15.8, 6.1);
uniform vec4 tug_shape = vec4(12.0, 18.4, 4.3, 2.8);
varying vec3 sea_position;
varying float crest;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fade = near_water ? 1.0 - smoothstep(22.0, 30.0, max(abs(VERTEX.x), abs(VERTEX.z))) : 0.0;
	// Two long swells at an angle to each other, so the crests wander instead of marching in rows.
	float swell = sin(world.x * 0.22 + world.z * 0.09 + TIME * swell_speed) * 0.65
		+ sin(world.z * 0.31 - world.x * 0.07 + TIME * swell_speed * 1.3) * 0.35;
	float ripples = (sin(world.x * 0.7 + TIME * wave_speed) + cos(world.z * 0.9 + TIME * wave_speed)) * 0.5;
	VERTEX.y += (swell * swell_height + ripples * wave_height) * fade;
	crest = swell * fade;
	sea_position = world;
}
float hull_edge(vec2 p, vec4 shape) {
	// Roughly metres from p to a rounded box (a superellipse) around a hull; zero on its outline.
	vec2 q = abs(p - shape.xy) / shape.zw;
	float size = pow(pow(q.x, 4.0) + pow(q.y, 4.0), 0.25);
	return abs(size - 1.0) * min(shape.z, shape.w);
}
void fragment() {
	vec2 p = sea_position.xz;
	float ripples = sin(p.x * 2.0 + TIME) * cos(p.y * 2.8 + TIME * 0.6);
	// Broken, drifting foam rather than a solid line: it thins and gathers along the outline as it moves.
	float drift = 0.5 + 0.5 * sin(p.x * 1.3 + p.y * 0.7 + TIME * 0.9) * sin(p.x * 0.4 - p.y * 1.1 - TIME * 0.6);
	float hull_foam = (1.0 - smoothstep(0.0, 0.45, hull_edge(p, hull_shape))) * drift;
	float tug_foam = (1.0 - smoothstep(0.0, 0.35, hull_edge(p, tug_shape))) * drift;
	float streaks = 0.5 + 0.5 * sin(p.x * 0.9 + p.y * 1.7 + TIME * 0.5);
	float crest_foam = smoothstep(0.6, 0.95, crest) * streaks;
	float foam = max(max(hull_foam, tug_foam) * 0.32, crest_foam * 0.25);
	// Troughs a touch darker than crests, so the swell reads from the party camera.
	vec3 body = water_colour.rgb * (0.86 + 0.14 * clamp(crest * 0.5 + 0.5, 0.0, 1.0) + ripples * 0.025);
	ALBEDO = body + vec3(0.4, 0.48, 0.56) * foam;
	ROUGHNESS = 0.8;
	NORMAL_MAP = vec3(0.5 + sin(p.x * 1.5 + TIME) * 0.04, 0.5 + cos(p.y * 1.4 + TIME) * 0.04, 1.0);
}
