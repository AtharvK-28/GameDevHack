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
		"joystickFollow": SETTINGS.JOYSTICK_FOLLOW,
		"stickSendRate": SETTINGS.STICK_SEND_RATE,
		"throwFlickStick": SETTINGS.THROW_FLICK_STICK, # How far the stick must be pushed for a release to throw.
		"ghostEnergyMax": SETTINGS.ENERGY_MAX,
		"ghostNearBuzzMs": SETTINGS.GHOST_NEAR_BUZZ_MS,
		"ghostNearPulseMs": SETTINGS.GHOST_NEAR_PULSE_MS,
		"buzz": { # The phone's own haptics (decision 149).
			"grab": SETTINGS.BUZZ_GRAB_MS,
			"letGo": SETTINGS.BUZZ_LET_GO_MS,
			"throw": SETTINGS.BUZZ_THROW_MS,
			"brace": SETTINGS.BUZZ_BRACE_MS,
			"shout": SETTINGS.BUZZ_SHOUT_MS,
			"ui": SETTINGS.BUZZ_UI_MS,
			"ghostAction": SETTINGS.BUZZ_GHOST_ACTION_MS,
			"refused": SETTINGS.BUZZ_REFUSED_MS,
		},
	}
	var file := FileAccess.open("res://controller/settings.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write controller/settings.json")
		quit(1)
		return
	file.store_string(JSON.stringify(settings, "\t") + "\n")
	print("Generated controller/settings.json from Balance.gd")
	quit()
