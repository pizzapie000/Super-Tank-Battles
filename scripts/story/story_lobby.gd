extends Control

const ControllerInput = preload("res://scripts/input/controller_input.gd")

var roster: VBoxContainer
var start_button: Button
var status: Label
var fading: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	StorySession.devices = [-1]
	var backdrop := ColorRect.new()
	backdrop.color = Color("101923")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var column := VBoxContainer.new()
	column.position = Vector2(250, 70 if StorySession.debug_checkpoint >= 0 else 105)
	column.size = Vector2(780, 700 if StorySession.debug_checkpoint >= 0 else 650)
	column.add_theme_constant_override("separation", 16 if StorySession.debug_checkpoint >= 0 else 20)
	add_child(column)
	add_label(column, "TRUE CAMPAIGN / ASSEMBLE YOUR CREW", 30)
	if StorySession.debug_checkpoint >= 0:
		var checkpoints := StorySession.available_checkpoints()
		var selected: Dictionary = checkpoints[clampi(StorySession.debug_checkpoint, 0, checkpoints.size() - 1)]
		add_label(column, "DEBUG · %02d / %s · Progress is not saved" % [selected.index + 1, selected.title], 18)
	add_label(column, "A shared story for 1–4 players on this computer.\nControllers: press A / Cross to join; B / Circle to leave.\nTab toggles the keyboard player so four controllers can join.", 19)
	roster = VBoxContainer.new()
	roster.add_theme_constant_override("separation", 12)
	column.add_child(roster)
	status = add_label(column, "", 17)
	start_button = add_button(column, "BEGIN THE ADVENTURE" if not StorySession.resume_story else "CONTINUE FROM CHECKPOINT", start_story)
	if StorySession.debug_checkpoint >= 0:
		start_button.text = "TEST THIS CHECKPOINT"
	add_button(column, "KEYBOARD ON / OFF", toggle_keyboard)
	add_button(column, "BACK TO MODES", back)
	add_label(column, "Keyboard: WASD move • Mouse aim • Click fire • E mine • F help\nController: left stick move • right stick aim • RT / R2 fire • B / Circle mine\nHold A / Cross beside a downed friend to revive. Start pauses.", 17)
	ControllerInput.connect_changes(connection_changed)
	refresh()
	start_button.grab_focus()
	var wii_button := add_button(self, "WII REMOTE SETUP", show_wii_setup)
	wii_button.position = Vector2(1010, 20)
	wii_button.size = Vector2(240, 38)
	wii_button.custom_minimum_size.y = 38
	wii_button.add_theme_font_size_override("font_size", 14)
	preload("res://scripts/input/wii_menu.gd").attach(self, back, [], func(device: int): return not StorySession.devices.has(device), func(): return not fading)

func show_wii_setup() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var setup = preload("res://scenes/game/WiiSetup.tscn").instantiate()
	setup.closed.connect(func():
		setup.queue_free()
		refresh()
		if is_instance_valid(previous_focus): previous_focus.grab_focus()
	)
	add_child(setup)

func add_label(parent: Node, value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("dce8ed"))
	parent.add_child(label)
	return label

func add_button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func refresh() -> void:
	for child in roster.get_children():
		roster.remove_child(child)
		child.queue_free()
	for i in range(4):
		var description := "OPEN SLOT — press A on a controller"
		if i < StorySession.devices.size():
			var device := StorySession.devices[i]
			description = "Keyboard + mouse" if device < 0 else ControllerInput.device_name(device)
		var label := add_label(roster, "P%d    %s" % [i + 1, description], 22)
		label.add_theme_color_override("font_color", DuelTank.readable_tint(StorySession.COLORS[i]))
	start_button.disabled = StorySession.devices.is_empty()
	status.text = "%d / 4 players ready. Enter or Start begins." % StorySession.devices.size()

func toggle_keyboard() -> void:
	if StorySession.devices.has(-1):
		StorySession.devices.erase(-1)
	elif StorySession.devices.size() < 4:
		StorySession.devices.push_front(-1)
	refresh()

func connection_changed(device: int, connected: bool) -> void:
	if not connected:
		StorySession.devices.erase(device)
	refresh()

func _input(event: InputEvent) -> void:
	if fading:
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A and not StorySession.devices.has(event.device):
			StorySession.add_device(event.device)
			refresh()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_B:
			StorySession.devices.erase(event.device)
			refresh()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_START:
			if StorySession.devices.is_empty():
				StorySession.add_device(event.device)
			start_story()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			toggle_keyboard()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE:
			back()

func start_story() -> void:
	if fading or StorySession.devices.is_empty():
		return
	fading = true
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.65)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/story/Adventure.tscn"))

func back() -> void:
	if not fading:
		get_tree().change_scene_to_file("res://scenes/game/MainMenu.tscn")
