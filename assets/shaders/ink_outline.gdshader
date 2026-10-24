// Comic ink outline: the mesh drawn again, pushed out along its normals and seen only from behind, so a dark rim
// shows around the silhouette. A material overlay on the movers, and a next pass on loot and furniture.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.07, 0.04, 0.11, 1.0);
uniform float width = 0.02; // World metres the rim reaches out from the surface, whatever the model's scale.

void vertex() {
	VERTEX += NORMAL * width / max(length(MODEL_MATRIX[0].xyz), 0.0001);
}

void fragment() {
	ALBEDO = ink.rgb;
}
