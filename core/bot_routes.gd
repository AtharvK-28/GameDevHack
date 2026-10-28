# Route maps for developer mode's playing stand-ins (core/bot_crew.gd), taken from the recording bots in tools/.
# Per arena scene: floor points (y is the deck height), the walkable links between them, where held loot is dropped,
# and the two-person item's path to the truck with a stand at each end. Geometry, not tuning.
extends RefCounted

const ROUTES: Dictionary = {
	"res://arenas/Mansion.tscn": {
		"nodes": {
			"g_stairs": Vector3(1.5, 1.2, 4.6), "g_west": Vector3(3.4, 1.2, 4.6), "g_lib": Vector3(6.6, 1.2, 4.6),
			"g_mid": Vector3(10.0, 1.2, 5.0), "g_hall": Vector3(12.4, 1.2, 4.4), "g_bed": Vector3(15.0, 1.2, 3.4),
			"g_tv": Vector3(18.0, 1.2, 3.0),
			"m_west": Vector3(1.5, 0.0, 11.6), "m_centre": Vector3(5.5, 0.0, 11.5), "m_north": Vector3(7.0, 0.0, 8.6),
			"m_east": Vector3(11.0, 0.0, 11.0), "m_door": Vector3(7.75, 0.0, 13.4),
			"k_door": Vector3(13.2, 0.0, 11.0), "k_centre": Vector3(15.5, 0.0, 9.2), "k_east": Vector3(18.0, 0.0, 12.0),
			"k_corner": Vector3(18.0, 0.0, 13.9),
			"o_porch": Vector3(7.75, 0.0, 16.6), "o_path": Vector3(7.75, 0.0, 19.5), "truck": Vector3(7.75, 0.0, 21.2),
			"o_gate": Vector3(9.0, 0.0, 16.5), "gd_in": Vector3(11.2, 0.0, 16.5), "gd_path": Vector3(12.8, 0.0, 18.0),
			"gd_east": Vector3(16.6, 0.0, 16.4),
		},
		"edges": [
			["g_stairs", "g_west"], ["g_west", "g_lib"], ["g_lib", "g_mid"], ["g_mid", "g_hall"], ["g_hall", "g_bed"],
			["g_bed", "g_tv"], ["g_stairs", "m_west"], ["m_west", "m_centre"], ["m_centre", "m_north"],
			["m_centre", "m_door"], ["m_centre", "m_east"], ["m_north", "m_east"], ["m_east", "m_door"],
			["m_east", "k_door"], ["k_door", "k_centre"], ["k_door", "k_east"], ["k_centre", "k_east"],
			["k_east", "k_corner"], ["m_door", "o_porch"], ["o_porch", "o_path"], ["o_path", "truck"],
			["o_porch", "o_gate"], ["o_gate", "gd_in"], ["gd_in", "gd_path"], ["gd_in", "gd_east"], ["gd_path", "gd_east"],
		],
		"delivery": Vector3(7.75, 0.0, 22.6), # On the driveway at the tailgate.
		"pair_path": [
			Vector2(6.5, 3.6), Vector2(2.7, 3.8), Vector2(1.6, 7.0), Vector2(1.5, 11.8), Vector2(4.5, 12.8),
			Vector2(7.75, 13.4), Vector2(7.75, 16.8), Vector2(7.75, 19.8), Vector2(7.75, 21.6),
		],
		"pair_stands": [Vector3(7.85, 1.2, 3.0), Vector3(12.15, 1.2, 3.0)], # The piano's west and east ends.
	},
	"res://arenas/Ship.tscn": {
		"nodes": {
			"q_back": Vector3(3.5, 1.2, 2.6), "q_mid": Vector3(4.6, 1.2, 6.0), "q_front": Vector3(3.5, 1.2, 9.4),
			"sb_top": Vector3(5.6, 1.2, 2.55), "sb_foot": Vector3(10.4, 0.0, 2.55),
			"sf_top": Vector3(5.6, 1.2, 9.45), "sf_foot": Vector3(10.4, 0.0, 9.45),
			"m_back_w": Vector3(11.2, 0.0, 3.4), "m_back_e": Vector3(17.6, 0.0, 2.8), "m_centre": Vector3(13.2, 0.0, 5.0),
			"m_east": Vector3(17.8, 0.0, 4.2), "m_port": Vector3(12.0, 0.0, 9.2), "m_front_e": Vector3(14.5, 0.0, 9.6),
			"fb_foot": Vector3(18.0, 0.0, 2.8), "fb_top": Vector3(21.2, 0.7, 2.8),
			"ff_foot": Vector3(18.0, 0.0, 9.1), "ff_top": Vector3(21.2, 0.7, 9.1),
			"f_back": Vector3(24.4, 0.7, 3.0), "f_mid": Vector3(24.6, 0.7, 6.2), "f_bow": Vector3(25.6, 0.7, 7.6),
			"p_port": Vector3(12.0, 0.0, 11.3), "p_mid": Vector3(12.0, 0.0, 14.0), "tug": Vector3(12.0, 0.0, 17.0),
		},
		"edges": [
			["q_back", "q_mid"], ["q_mid", "q_front"], ["q_back", "sb_top"], ["sb_top", "sb_foot"], ["q_front", "sf_top"],
			["sf_top", "sf_foot"], ["sb_foot", "m_back_w"], ["m_back_w", "m_centre"], ["m_back_w", "m_back_e"],
			["m_centre", "m_east"], ["m_centre", "m_port"], ["m_east", "m_back_e"], ["sf_foot", "m_port"],
			["m_port", "m_front_e"], ["m_front_e", "ff_foot"], ["m_back_e", "fb_foot"], ["ff_foot", "ff_top"],
			["fb_foot", "fb_top"], ["fb_top", "f_back"], ["f_back", "f_mid"], ["f_mid", "f_bow"],
			["m_port", "p_port"], ["p_port", "p_mid"], ["p_mid", "tug"],
		],
		"delivery": Vector3(12.0, 0.0, 17.4), # On the tug.
		"pair_path": [Vector2(19.6, 8.9), Vector2(12.0, 8.9), Vector2(12.0, 11.3), Vector2(12.0, 18.0)],
		"pair_stands": [Vector3(21.7, 0.7, 8.8), Vector3(25.4, 0.7, 8.2)], # The chest's west and east ends.
		"plank_lanes": true, # Two lanes over the gangplank, so movers pass instead of meeting nose to nose.
	},
	"res://arenas/Museum.tscn": {
		# One floor. Bots go in and out by the laser hall, never the revolving door, and cross the lasers as they find them.
		"nodes": {
			"e_west": Vector3(3.0, 0.0, 3.6), "e_centre": Vector3(5.0, 0.0, 5.0), "e_east": Vector3(7.4, 0.0, 4.2),
			"e_door_art": Vector3(5.0, 0.0, 7.0), "e_door_rot": Vector3(9.0, 0.0, 4.3),
			"r_west": Vector3(11.0, 0.0, 4.3), "r_centre": Vector3(13.8, 0.0, 5.0), "r_east": Vector3(19.0, 0.0, 4.3),
			"r_door_hall": Vector3(15.0, 0.0, 7.0),
			"j_west": Vector3(21.0, 0.0, 4.3), "j_centre": Vector3(24.5, 0.0, 5.2), "j_door_space": Vector3(25.0, 0.0, 7.2),
			"a_door_egypt": Vector3(5.0, 0.0, 9.0), "a_west": Vector3(2.6, 0.0, 11.5), "a_centre": Vector3(5.0, 0.0, 11.5),
			"a_east": Vector3(9.0, 0.0, 11.5),
			"g_west": Vector3(11.2, 0.0, 11.5), "g_north": Vector3(15.0, 0.0, 9.2), "g_centre": Vector3(15.0, 0.0, 11.5),
			"g_south": Vector3(15.0, 0.0, 13.8), "g_east": Vector3(18.8, 0.0, 11.5),
			"s_west": Vector3(21.0, 0.0, 11.5), "s_centre": Vector3(24.6, 0.0, 10.2), "s_door_jur": Vector3(25.0, 0.0, 9.0),
			"s_door_lobby": Vector3(25.0, 0.0, 14.2),
			"l_space": Vector3(25.0, 0.0, 16.4), "l_east": Vector3(21.0, 0.0, 17.3), "l_hall": Vector3(15.0, 0.0, 17.3),
			"l_west": Vector3(13.0, 0.0, 17.3),
			"h_east": Vector3(10.5, 0.0, 17.3), "h_mid": Vector3(6.5, 0.0, 17.3), "h_west": Vector3(2.1, 0.0, 17.3),
			"h_exit": Vector3(2.1, 0.0, 19.6), "truck": Vector3(2.6, 0.0, 21.4),
		},
		"edges": [
			["e_west", "e_centre"], ["e_centre", "e_east"], ["e_centre", "e_door_art"], ["e_east", "e_door_rot"],
			["e_door_rot", "r_west"], ["r_west", "r_centre"], ["r_centre", "r_door_hall"], ["r_centre", "r_east"],
			["r_east", "j_west"], ["j_west", "j_centre"], ["j_centre", "j_door_space"], ["e_door_art", "a_door_egypt"],
			["a_door_egypt", "a_centre"], ["a_west", "a_centre"], ["a_centre", "a_east"], ["a_east", "g_west"],
			["g_west", "g_centre"], ["g_north", "g_centre"], ["g_north", "r_door_hall"], ["g_centre", "g_east"],
			["g_centre", "g_south"], ["g_east", "s_west"], ["s_west", "s_centre"], ["s_centre", "s_door_jur"],
			["s_door_jur", "j_door_space"], ["s_centre", "s_door_lobby"], ["s_door_lobby", "l_space"], ["l_space", "l_east"],
			["l_east", "l_hall"], ["l_hall", "g_south"], ["l_hall", "l_west"], ["l_west", "h_east"], ["h_east", "h_mid"],
			["h_mid", "h_west"], ["h_west", "h_exit"], ["h_exit", "truck"],
		],
		"delivery": Vector3(2.6, 0.0, 22.0), # At the van's tailgate.
		"pair_path": [
			# In the laser hall the pair stops between the gates (6.25), never beside one.
			Vector2(12.3, 5.8), Vector2(15.0, 6.0), Vector2(15.0, 11.5), Vector2(15.0, 17.3), Vector2(10.8, 17.3),
			Vector2(6.25, 17.3), Vector2(2.1, 17.3), Vector2(2.1, 21.6),
		],
		"pair_stands": [Vector3(10.6, 0.0, 2.3), Vector3(14.0, 0.0, 2.3)], # The skull's west and east ends, on its bracket.
	},
}
