# Checks the Old Mansion's upgrade (decision 140) in the real game world: the personality loot (the cat in a box,
# the fish tank, the cursed doll and the chiming grandfather clock), the bonus goal and award they bring, and the
# ghost possessing every kind of furniture in a match.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var checks: Node = load("res://core/mansion_checks.gd").new()
	root.add_child(checks)
	var failures: int = await checks.run()
	print("MANSION CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
