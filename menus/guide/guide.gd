# Explains the current phone controls and round objective; Back or Escape returns to the home menu.
extends Control

# --- Setup ---
func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Balance.UI_PANEL_MARGIN * 2)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)
	margin.add_child(column)
	column.add_child(_label("How to play", &"HeadingLabel"))
	column.add_child(_label("2-4 phones | One ghost | Roles rotate each round", &"MutedLabel"))

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	var roles := HBoxContainer.new()
	roles.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN * 2)
	panel.add_child(roles)
	roles.add_child(_role("MOVERS", "Stick to move. Hold GRAB to carry; release in the green truck zone to bank. Bumps lose value. THROW light loot only.\nTwo movers carry the piano; dragging loses value.\nWhen SHAKE warns you, stop or BRACE."))
	roles.add_child(_role("GHOST", "Fly through walls. POSSESS loose loot or the sofa, steer, then SHOVE. LEAVE to refill energy.\nSHAKE tumbles moving movers. CURSE slows carriers. Buttons show costs and cooldowns.\nDoor, chandelier, armour and rug abilities are disabled in this demo."))
	column.add_child(_label("Bank 70% before time runs out to win as movers. Lose more than 30% and the ghost wins.", &"BodyLabel"))
	column.add_child(_label("Scan QR on the same Wi-Fi, enter a name and tap Ready. The host starts with 2+ ready phones.", &"MutedLabel"))

	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(hide)
	column.add_child(back)
	back.grab_focus.call_deferred()


# --- Navigation ---
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


# --- Helpers ---
func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _role(title: String, body: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = "[b]" + title + "[/b]\n" + body
	return text
