// Comic ink outline: the mesh drawn again, pushed out along its normals and seen only from behind, so a dark rim
// shows around the silhouette. Used as a material overlay on the movers.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.07, 0.04, 0.11, 1.0);
uniform float width = 0.02; // Metres the rim reaches out from the surface.

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
}
