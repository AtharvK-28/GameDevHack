# Base for global hauntings: trigger() runs warn() and warning() for warning_time, then run() and running() for
# run_time, then end(). The ghost checks and pays the energy cost first; the cooldown starts on the trigger.
class_name Haunting
extends Node

enum Phase { IDLE, WARNING, RUNNING }

# --- Settings, set by each haunting ---
var label: String = ""
var cost: int = 0
var cooldown: float = 0.0
var warning_time: float = 0.0
var run_time: float = 0.0

# --- Haunting state ---
var phase: Phase = Phase.IDLE
var phase_left: float = 0.0
var cooldown_left: float = 0.0
var ghost: Node3D

# --- Triggering ---
func can_trigger() -> bool:
	return phase == Phase.IDLE and cooldown_left <= 0.0


func cooldown_fraction() -> float:
	return clampf(cooldown_left / cooldown, 0.0, 1.0) if cooldown > 0.0 else 0.0


func is_active() -> bool:
	return phase != Phase.IDLE


func trigger(by: Node3D) -> void:
	ghost = by
	cooldown_left = cooldown
	print("Ghost triggered %s" % label)
	if warning_time > 0.0:
		phase = Phase.WARNING
		phase_left = warning_time
		warn()
	else:
		_start_running()


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if phase == Phase.WARNING:
		warning(delta)
		phase_left -= delta
		if phase_left <= 0.0:
			_start_running()
	elif phase == Phase.RUNNING:
		running(delta)
		phase_left -= delta
		if phase_left <= 0.0:
			phase = Phase.IDLE
			end()


func _start_running() -> void:
	phase = Phase.RUNNING
	phase_left = run_time
	run()


# --- Hooks for each haunting ---
func warn() -> void:
	pass


func warning(_delta: float) -> void:
	pass


func run() -> void:
	pass


func running(_delta: float) -> void:
	pass


func end() -> void:
	pass
