# The Museum's ghost: Bahadur, the night watchman who guarded the museum for forty years and never clocked off.
# Built from simple low-poly shapes like the Captain, and animated by the Captain's code (hover, turn, lean, the
# actions' pops and shakes); only his body differs: a khaki uniform with a belt and whistle, a peaked cap, a big
# moustache, a lathi in one hand and a torch in the other.
class_name GhostWatchmanModel
extends GhostCaptainModel

func _build() -> void:
	# Heights are from the tip of his tail; he stands about 2.0 m to the cap, over the 1.6 m movers.
	_part(_cylinder(0.38, 0.04, 0.75), Vector3(0, 0.38, 0), Balance.WATCHMAN_TAIL_COLOUR)
	# Khaki shirt and trousers, a brown belt with a brass buckle, shoulder flashes and a whistle on a cord.
	_part(_cylinder(0.3, 0.38, 0.8), Vector3(0, 1.0, 0), Balance.WATCHMAN_KHAKI)
	_part(_cylinder(0.33, 0.33, 0.08), Vector3(0, 0.84, 0), Balance.WATCHMAN_BELT)
	_part(_box(Vector3(0.11, 0.08, 0.04)), Vector3(0, 0.84, 0.33), Balance.WATCHMAN_BRASS)
	_part(_box(Vector3(0.05, 0.22, 0.02)), Vector3(0.12, 1.22, 0.29), Balance.WATCHMAN_CORD)
	_part(_cylinder(0.03, 0.03, 0.09), Vector3(0.12, 1.1, 0.31), Balance.WATCHMAN_BRASS).rotation.x = PI / 2.0
	for side: float in [-1.0, 1.0]:
		_part(_box(Vector3(0.16, 0.04, 0.1)), Vector3(side * 0.27, 1.38, 0), Balance.WATCHMAN_DARK)
		var arm: MeshInstance3D = _part(_capsule(0.08, 0.6), Vector3(side * 0.38, 1.12, 0.05), Balance.WATCHMAN_KHAKI)
		arm.rotation = Vector3(-0.3, 0, side * 0.3)
		_part(_sphere(0.075), Vector3(side * 0.47, 0.86, 0.14), Balance.WATCHMAN_SKIN)
	# The lathi, the watchman's long bamboo stick, held upright in his right hand.
	_part(_cylinder(0.025, 0.025, 1.5), Vector3(0.5, 1.15, 0.16), Balance.WATCHMAN_LATHI)
	# The torch in his left hand, its lens glowing.
	_part(_cylinder(0.05, 0.05, 0.22), Vector3(-0.47, 0.86, 0.26), Balance.WATCHMAN_DARK).rotation.x = PI / 2.0
	_part(_cylinder(0.065, 0.05, 0.05), Vector3(-0.47, 0.86, 0.38), Balance.WATCHMAN_TORCH).rotation.x = PI / 2.0
	# Head, glowing eyes, and the moustache that made him famous: two curled wings.
	_part(_sphere(0.2), Vector3(0, 1.58, 0), Balance.WATCHMAN_SKIN)
	for side: float in [-0.075, 0.075]:
		_part(_sphere(0.035), Vector3(side, 1.62, 0.17), Balance.CAPTAIN_EYE_COLOUR)
	for side: float in [-1.0, 1.0]:
		var wing: MeshInstance3D = _part(_capsule(0.035, 0.24), Vector3(side * 0.1, 1.51, 0.19), Balance.WATCHMAN_MOUSTACHE)
		wing.rotation = Vector3(0, 0, side * 1.25)
		_part(_sphere(0.04), Vector3(side * 0.21, 1.55, 0.17), Balance.WATCHMAN_MOUSTACHE)
	# A peaked cap with a badge.
	_part(_cylinder(0.21, 0.2, 0.14), Vector3(0, 1.79, 0), Balance.WATCHMAN_CAP)
	var peak: MeshInstance3D = _part(_box(Vector3(0.3, 0.03, 0.16)), Vector3(0, 1.73, 0.2), Balance.WATCHMAN_DARK)
	peak.rotation.x = 0.25
	_part(_box(Vector3(0.08, 0.07, 0.02)), Vector3(0, 1.8, 0.21), Balance.WATCHMAN_BRASS)
