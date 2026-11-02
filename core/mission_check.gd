# Checks the Sabotage Showdown's mission (decision 158): that its four steps really are a sequence, that the stair
# gate keeps the gallery out of reach until the power is on, that the fuse box answers movers and the ghost both,
# and that the wire puzzle only accepts matching pairs.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var checks: Node = load("res://core/mission_checks.gd").new()
	root.add_child(checks)
	var failures: int = await checks.run()
	print("MISSION CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
