# Generates browser settings from Balance; run after changing shared tuning values.
extends SceneTree

const SETTINGS := preload("res://autoload/Balance.gd")

func _initialize() -> void:
	var settings: Dictionary = {
		"socketPort": SETTINGS.SOCKET_PORT,
		"inputRate": SETTINGS.INPUT_RATE,
		"reconnectDelayMs": SETTINGS.RECONNECT_DELAY_MS,
		"maxNameLength": SETTINGS.MAX_NAME_LENGTH,
		"joinCodeLength": SETTINGS.JOIN_CODE_LENGTH,
		"joystickSize": SETTINGS.JOYSTICK_SIZE,
		"joystickDeadzone": SETTINGS.JOYSTICK_DEADZONE,
		"ghostEnergyMax": SETTINGS.ENERGY_MAX,
		"ghostNearBuzzMs": SETTINGS.GHOST_NEAR_BUZZ_MS,
		"ghostNearPulseMs": SETTINGS.GHOST_NEAR_PULSE_MS,
	}
	var file := FileAccess.open("res://controller/settings.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write controller/settings.json")
		quit(1)
		return
	file.store_string(JSON.stringify(settings, "\t") + "\n")
	print("Generated controller/settings.json from Balance.gd")
	quit()
