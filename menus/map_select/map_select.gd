# Map select, opened by the title's Play: the host picks a house with the mouse or the keyboard. The Mansion is
# playable; the Ghost Ship and the Abandoned Museum are locked "coming soon" tiles. Esc or Back returns to the
# title (Maaack's MainMenu closes a sub menu when it hides).
extends Control

signal map_chosen(arena_path: String)

const Style := preload("res://screens/screen_style.gd")

# --- Maps (an empty arena path means locked) ---
static func maps() -> Array[Dictionary]:
	return [
		{"name": "Old Mansion", "note": "Gallery, stairs and a grand piano", "arena": "res://arenas/Mansion.tscn", "preview": Balance.MAP_PREVIEW_ART, "crop": Balance.MAP_PREVIEW_CROP},
		{"name": "Ghost Ship", "note": "Coming soon", "arena": "", "preview": ""},
		{"name": "Abandoned Museum", "note": "Coming soon", "arena": "", "preview": ""},
	]

var first_tile: Button

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN * 2)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	var heading := Style.lettering("CHOOSE A HOUSE", Balance.MENU_TITLE_SIZE, Balance.UI_MONEY)
	column.add_child(heading)

	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN * 2)
	column.add_child(tiles)
	for map: Dictionary in maps():
		tiles.add_child(_tile(map))

	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(hide)
	column.add_child(back)
	first_tile.grab_focus.call_deferred()
	UiMotion.pop_in(tiles)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


# --- Tiles ---
func _tile(map: Dictionary) -> Button:
	var locked: bool = map.arena.is_empty()
	var tile := Button.new()
	tile.theme_type_variation = &"TileButton"
	tile.custom_minimum_size = Balance.MAP_TILE_SIZE
	tile.disabled = locked
	if not locked:
		tile.pressed.connect(func() -> void: map_chosen.emit(map.arena))
		if first_tile == null:
			first_tile = tile

	var inside := VBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, Balance.UI_PANEL_MARGIN)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(inside)
	inside.add_child(_locked_art() if locked else _preview(map))
	inside.add_child(_label(map.name, &"HeadingLabel"))
	inside.add_child(_label(map.note, &"MutedLabel"))
	return tile


func _preview(map: Dictionary) -> Control:
	# The house's comic art from the intro, framed in ink.
	var frame := Style.ink_panel(0.0, Balance.COMIC_BORDER)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var picture := TextureRect.new()
	var crop := AtlasTexture.new()
	crop.atlas = load(map.preview)
	crop.region = map.crop
	picture.texture = crop
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	return frame


func _locked_art() -> Control:
	# A mystery house: a big question mark with COMING SOON stamped across it.
	var art := CenterContainer.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -Balance.UI_PANEL_MARGIN * 2) # The stamp overlaps the "?".
	art.add_child(stack)
	stack.add_child(Style.lettering("?", Balance.COMIC_TITLE_SIZE * 2, Balance.UI_MUTED))
	var stamp := Style.stamp("COMING SOON", Balance.UI_DANGER, Balance.COMIC_LABEL_SIZE)
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(stamp)
	return art


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
