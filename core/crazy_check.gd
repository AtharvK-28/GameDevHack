# Checks the crazy ideas in the real game world, on the Mansion's front lawn: the Haunted Controller (decision 142),
# the ghost's HEX that scrambles a mover's phone.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var checks: Node = load("res://core/crazy_checks.gd").new()
	root.add_child(checks)
	var failures: int = await checks.run()
	print("CRAZY CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
