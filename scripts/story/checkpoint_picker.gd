extends Control

const ControlHints = preload("res://scripts/input/control_hints.gd")
signal checkpoint_selected(index: int)
signal closed

var current_checkpoint: int = 0
var allowed_devices: Array[int] = []
var checkpoint_buttons: Array[Button] = []
var back_button: Button
var scroll: ScrollContainer
var axis_directions: Dictionary = {}
var heading: String = "DEBUG / CHOOSE A CHECKPOINT"
var description: String = "Start with a fresh crew. Test runs leave your adventure save untouched."
var item_name: String = "checkpoints"
var entries: Array[Dictionary] = []
var control_hint_label: Label
var checkpoint_count := 0

func _ready() -> void:
	name = "CheckpointPicker"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var picker_theme := Theme.new()
	picker_theme.default_font = ThemeDB.fallback_font
	picker_theme.default_font_size = 17
	theme = picker_theme
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(150, 64)
	panel.size = Vector2(980, 672)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172631")
	style.border_color = Color("ffd575")
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(7)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	add_label(column, heading, 29, Color("ffd575"))
	add_label(column, description, 17, Color("bdcbd1"))
	var checkpoints := entries if not entries.is_empty() else StorySession.available_checkpoints()
	checkpoint_count = checkpoints.size()
	control_hint_label = Label.new()
	control_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_hint_label.add_theme_font_size_override("font_size", 14)
	control_hint_label.add_theme_color_override("font_color", Color("8296a5"))
	column.add_child(control_hint_label)
	refresh_control_hint()
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 420
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for checkpoint in checkpoints:
		var button := Button.new()
		button.text = checkpoint.label if checkpoint.has("label") else "%02d  /  %s    ·    %s" % [checkpoint.index + 1, checkpoint.title, checkpoint.biome]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 44
		button.pressed.connect(func(): checkpoint_selected.emit(checkpoint.index))
		list.add_child(button)
		checkpoint_buttons.append(button)
	back_button = Button.new()
	back_button.text = "CANCEL"
	back_button.custom_minimum_size.y = 44
	back_button.pressed.connect(func(): closed.emit())
	column.add_child(back_button)
	if not checkpoint_buttons.is_empty():
		checkpoint_buttons[clampi(current_checkpoint, 0, checkpoint_buttons.size() - 1)].grab_focus()
	else:
		back_button.grab_focus()
	keep_focus_visible.call_deferred()
	preload("res://scripts/input/wii_menu.gd").attach(self, func(): closed.emit(), allowed_devices)

func refresh_control_hint() -> void:
	var devices := allowed_devices if not allowed_devices.is_empty() else PlayerSetup.selected()
	control_hint_label.text = "%d %s · %s" % [checkpoint_count, item_name, ControlHints.menu_hint(devices)]

func _process(_delta: float) -> void:
	refresh_control_hint()

func add_label(parent: Node, value: String, font_size: int, tint: Color) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)

func keep_focus_visible() -> void:
	if not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and scroll.is_ancestor_of(focused):
		scroll.ensure_control_visible(focused)

func move_focus(direction: int) -> void:
	var buttons := checkpoint_buttons.duplicate()
	buttons.append(back_button)
	var index := buttons.find(get_viewport().gui_get_focus_owner())
	buttons[posmod(index + direction, buttons.size())].grab_focus()
	keep_focus_visible()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not allowed_devices.is_empty() and not allowed_devices.has(event.device):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
			var direction := int(signf(event.axis_value)) if absf(event.axis_value) > 0.6 else 0
			if direction != 0 and direction != axis_directions.get(event.device, 0):
				move_focus(direction)
			axis_directions[event.device] = direction
		elif event is InputEventJoypadButton and event.pressed:
			if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]:
				closed.emit()
			elif event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
				move_focus(-1 if event.button_index == JOY_BUTTON_DPAD_UP else 1)
			elif event.button_index == JOY_BUTTON_A:
				var focused := get_viewport().gui_get_focus_owner()
				if focused is Button and is_ancestor_of(focused):
					focused.pressed.emit()
		return
	if event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			get_viewport().set_input_as_handled()
			closed.emit()
		elif event.physical_keycode in [KEY_UP, KEY_DOWN, KEY_TAB]:
			move_focus(-1 if event.physical_keycode == KEY_UP or (event.physical_keycode == KEY_TAB and event.shift_pressed) else 1)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and is_ancestor_of(focused):
				focused.pressed.emit()
