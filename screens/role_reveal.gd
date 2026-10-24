# Role reveal, as a comic splash page: Seth-ji announces who he has possessed this round, the crew stands in a
# line-up (the ghost player glowing), and a stamped 3 → 2 → 1 → MOVE! countdown leads into live play.
extends Control

const Style := preload("res://screens/screen_style.gd")

# --- Display state ---
var round_label: Label
var bubble_text: RichTextLabel
var line_up := HBoxContainer.new()
var countdown: Control # A stamp; its text changes and it slams again each second.
var shown_count: String = ""

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style.use_theme(self)
	_build()
	Game.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	var count: String = "MOVE!" if Game.reveal_left <= Balance.REVEAL_MOVE_SECONDS else str(maxi(1, ceili(Game.reveal_left)))
	if count != shown_count:
		shown_count = count
		var text: Label = countdown.get_child(0).get_child(0)
		text.text = count
		text.add_theme_color_override("font_color", Balance.UI_GHOST if count == "MOVE!" else Balance.UI_MONEY)
		Style.slam(countdown)


# --- Refresh ---
func _refresh() -> void:
	var showing: bool = Game.phase in ["setup", "reveal"]
	if showing and not visible:
		shown_count = ""
	visible = showing
	if not visible:
		return
	round_label.text = "ROUND %d OF %d  ·  %s" % [Game.round_index + 1, Game.round_count, Game.arena_name().to_upper()]
	var ghost_name: String = Style.player_name(Game.ghost_slot).to_upper()
	var colour: String = Style.player_colour(Game.ghost_slot).to_html(false) if Game.ghost_slot >= 0 else "ffffff"
	bubble_text.text = "[b][color=#%s]%s[/color][/b] works for ME now!\nBreak everything!" % [colour, ghost_name]
	for figure: Node in line_up.get_children():
		figure.queue_free()
	for slot: int in Game.participants:
		line_up.add_child(_crew_member(slot, slot == Game.ghost_slot))


func _crew_member(slot: int, ghost: bool) -> Control:
	var member := VBoxContainer.new()
	member.add_theme_constant_override("separation", 0)
	member.alignment = BoxContainer.ALIGNMENT_CENTER
	var figure := Style.mover_figure(Style.player_colour(slot), Balance.REVEAL_FIGURE, ghost)
	figure.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	member.add_child(figure)
	var name_line := Style.label(Style.player_name(slot), Balance.UI_BODY_SIZE, Style.player_colour(slot))
	name_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	member.add_child(name_line)
	var role := Style.lettering("GHOST" if ghost else "MOVER", Balance.UI_SMALL_SIZE, Balance.UI_GHOST if ghost else Balance.UI_MUTED)
	role.add_theme_constant_override("outline_size", Balance.HOST_OUTLINE_SIZE)
	role.autowrap_mode = TextServer.AUTOWRAP_OFF
	member.add_child(role)
	return member


# --- Layout ---
func _build() -> void:
	add_child(Style.backdrop())
	var rows := Style.column()
	rows.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN)

	var narration := Style.caption(0.0, Balance.UI_PANEL_MARGIN / 2)
	narration.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	round_label = Style.lettering("", Balance.COMIC_LABEL_SIZE, Balance.COMIC_INK)
	round_label.add_theme_constant_override("outline_size", 0)
	round_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	narration.add_child(round_label)
	rows.add_child(narration)

	# Seth-ji's portrait, and his speech bubble with the line-up beneath it.
	var scene := HBoxContainer.new()
	scene.alignment = BoxContainer.ALIGNMENT_CENTER
	scene.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN * 2)
	rows.add_child(scene)
	var frame := Style.ink_panel(0.0, Balance.COMIC_BORDER)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait := TextureRect.new()
	var crop := AtlasTexture.new()
	crop.atlas = load(Balance.REVEAL_GHOST_ART)
	crop.region = Balance.REVEAL_GHOST_CROP
	portrait.texture = crop
	portrait.custom_minimum_size = Balance.REVEAL_PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(portrait)
	scene.add_child(frame)

	var speech := Style.column()
	speech.alignment = BoxContainer.ALIGNMENT_CENTER
	scene.add_child(speech)
	var bubble := Style.bubble("", Balance.UI_HEADING_SIZE)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bubble_text = bubble.get_child(0).get_child(0)
	speech.add_child(bubble)
	line_up.alignment = BoxContainer.ALIGNMENT_CENTER
	line_up.add_theme_constant_override("separation", Balance.UI_PANEL_MARGIN * 2)
	speech.add_child(line_up)
	var movers := Style.label("Movers: carry it to the truck. Don't break it.", Balance.UI_BODY_SIZE, Balance.UI_TEXT)
	speech.add_child(movers)

	countdown = Style.stamp("3", Balance.UI_MONEY, roundi(Balance.COMIC_TITLE_SIZE * 1.4))
	countdown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(countdown)
	var holder := CenterContainer.new() # Not Style.centre: the stamps animate themselves, a pop-in would fight them.
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rows)
	add_child(holder)
