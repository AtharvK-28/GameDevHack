# Checks the Captain's parrot (decision 127) on the real Ghost Ship: it spawns every round, rides calmly with a
# walking carrier, warns and then flies off from a running one, refuses throws, flies off from knocks and the sea
# without losing value, lands on a perch, and still banks on the tug.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var checks: Node = load("res://core/parrot_checks.gd").new()
	root.add_child(checks)
	var failures: int = await checks.run()
	print("PARROT CHECK: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
