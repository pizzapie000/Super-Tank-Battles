extends PanelContainer

signal changed
const Controls = preload("res://scripts/input/controller_input.gd")
var selectors: Array[OptionButton] = []
var status: Label
var timer := 0.0
var error := ""

func _ready() -> void:
	PlayerSetup.load_preferences()
	position = Vector2(55, 335)
	size = Vector2(530, 293)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172631")
	style.border_color = Color("51edcf")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var heading := Label.new()
	heading.text = "PLAYER SETUP / ALL MODES"
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	for slot in range(4):
		var row := HBoxContainer.new()
		column.add_child(row)
		var title := Label.new()
		title.text = "PLAYER %d" % (slot + 1)
		title.custom_minimum_size.x = 95
		title.add_theme_color_override("font_color", DuelTank.readable_tint(StorySession.COLORS[slot]))
		row.add_child(title)
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = 36
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.fit_to_longest_item = false
		selector.clip_text = true
		selector.item_selected.connect(func(index: int):
			error = PlayerSetup.assign(slot, int(selector.get_item_metadata(index)))
			refresh()
			changed.emit()
		)
		row.add_child(selector)
		selectors.append(selector)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	column.add_child(status)
	Controls.connect_changes(func(_device: int, _connected: bool): refresh())
	refresh()

func refresh() -> void:
	for slot in range(4):
		var selector := selectors[slot]
		if selector.get_popup().visible: continue
		selector.clear()
		var choices: Array[int] = [-1, -2, -3]
		if slot > 0: choices.push_front(PlayerSetup.OFF)
		choices.append_array(Controls.connected_devices())
		var current := PlayerSetup.device(slot)
		if not choices.has(current): choices.append(current)
		for choice in choices:
			selector.add_item(PlayerSetup.control_name(choice))
			# OptionButton treats ID -1 as automatic, but our keyboard device is -1.
			selector.set_item_metadata(selector.item_count - 1, choice)
			if choice == current: selector.select(selector.item_count - 1)
	status.text = error if not error.is_empty() else "Missions: P1 only · Duel: P1–P2 · Campaign: all active seats\nChoose each player's controls here before starting a mode."
	status.add_theme_color_override("font_color", Color("ffcc64") if not error.is_empty() else Color("a9bdc9"))

func show_problem(message: String) -> void:
	error = message
	refresh()
	selectors[0].grab_focus()

func _process(delta: float) -> void:
	timer += delta
	if timer >= 0.5:
		timer = 0
		refresh()
