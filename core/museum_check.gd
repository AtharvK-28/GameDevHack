# Checks the Museum of Mostly Real Things (decision 128) in the real game world: its loot pool and seeded rounds,
# exhibits resting on their pedestals, a mover reaching every gallery from the van, the T-Rex skull carried by two
# movers through the laser hall's doors to the van, and the moon rock's low-gravity throw.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var checks: Node = load("res://core/museum_checks.gd").new()
	root.add_child(checks)
	var failures: int = await checks.run()
	print("MUSEUM CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
