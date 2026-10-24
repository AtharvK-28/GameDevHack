# Runs the Ship's real physics and gameplay checks without opening the game menus.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var checks: Node = load("res://core/ship_checks.gd").new()
	root.add_child(checks)
	var failures: int = await checks.run()
	print("SHIP CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
