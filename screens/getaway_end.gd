# After The Getaway (decision 147): how much gold made it home, with up to three stars. It adds no points, so it never
# changes who won the match. Host key: Enter goes on to the epilogue, which also follows by itself.
extends Control

const Style := preload("res://screens/screen_style.gd")

var lines := VBoxContainer.new()
var left: float = 0.0

# --- Setup ---
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style.use_theme(self)
	add_child(Style.backdrop())
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", Balance.HOST_ROW_GAP * 3)
	var holder: Control = Style.centre(lines)
	add_child(holder)
	visible = false
	Game.changed.connect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if visible and Style.pressed_key(event) in [KEY_ENTER, KEY_KP_ENTER]:
		Game.finish_saved()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	left -= delta
	if left <= 0.0:
		Game.finish_saved()


func _refresh() -> void:
	var showing: bool = Game.phase == "saved"
	if showing and not visible:
		_show(Game.getaway_result)
	visible = showing


func _show(result: Dictionary) -> void:
	left = Balance.GETAWAY_RESULT_SECONDS
	for child: Node in lines.get_children():
		child.queue_free()
	var stamp: Control = Style.stamp("GOLD SAVED!", Balance.UI_MONEY, Balance.COMIC_TITLE_SIZE)
	var stamp_holder := CenterContainer.new()
	stamp_holder.add_child(stamp)
	lines.add_child(stamp_holder)
	Style.slam(stamp)
	var amount: Label = Style.lettering("%s of %s" % [Loot.rupees(result.saved), Loot.rupees(result.total)], Balance.COMIC_HEADING_SIZE, Balance.UI_TEXT)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(amount)
	var stars := CenterContainer.new()
	stars.add_child(Style.star_row(result.stars, Balance.GETAWAY_STAR_SHARES.size(), Balance.COMIC_TITLE_SIZE))
	lines.add_child(stars)
	Sfx.play("win", 1.0, Balance.SFX_JINGLE_DB)
