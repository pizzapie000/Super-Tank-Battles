extends Control

signal closed
const ControllerInput = preload("res://scripts/input/controller_input.gd")
@onready var wii: Node = ControllerInput.bridge()
var remote_select: OptionButton
var status_label: Label
var detail_label: Label
var calibrate_button: Button
var center_button: Button
var phase: int = -1
var first_corner := Vector2.ZERO
var message: String = ""
var back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	var background := ColorRect.new()
	background.color = Color("101923")
	background.show_behind_parent = true
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.position = Vector2(90, 25)
	column.size = Vector2(1100, 750)
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	set_meta("column", column)
	label(column, "WII REMOTE + NUNCHUK SETUP", 28)
	label(column, "Experimental controller support. Pair, calibrate and test each remote here before playing.", 14)
	label(column, "1. Start the bridge, then open Pair Remotes in its window. Allow Bluetooth if macOS asks.\n2. Press red SYNC once. Wait for Wii Remote Connected, then QUIT WiimotePair.\n3. Attach Nunchuks, press A to reconnect, then Scan in the bridge. Use SYNC only for a fresh pairing.\n4. Power the sensor bar, select each remote below, and calibrate its pointer before joining with A.", 16)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	button(actions, "START WII BRIDGE", func(): wii.launch_bridge())
	button(actions, "OPEN PAIRING APP", open_pairing)
	status_label = label(column, "", 16)
	remote_select = OptionButton.new()
	remote_select.custom_minimum_size.y = 38
	remote_select.item_selected.connect(func(_index: int): message = ""; queue_redraw())
	column.add_child(remote_select)
	var calibration_actions := HBoxContainer.new()
	calibration_actions.add_theme_constant_override("separation", 8)
	column.add_child(calibration_actions)
	calibrate_button = button(calibration_actions, "CALIBRATE POINTER", begin_calibration)
	center_button = button(calibration_actions, "CENTER NUNCHUK STICK", func(): wii.center_stick(selected_device()); message = "Stick centered. Release it before centering again.")
	detail_label = label(column, "", 16)
	detail_label.custom_minimum_size.y = 80
	var test_area := Control.new()
	test_area.custom_minimum_size.y = 95
	column.add_child(test_area)
	test_area.draw.connect(draw_test.bind(test_area))
	set_meta("test_area", test_area)
	label(column, "In battle: stick to drive • Point to aim • B to fire • Z for mines\nMenus: point + A to select • Stick / directional pad to browse • B / Z / 1 to go back\nPlus: skip intro / pause • Hold C or Minus for 2 seconds to skip training\nStand back with both ends of the powered sensor bar in view; keep the remote upright.", 14)
	back_button = button(column, "BACK", back)
	back_button.grab_focus()
	wii.state_changed.connect(refresh_remotes)
	refresh_remotes()
	preload("res://scripts/input/wii_menu.gd").attach(self, back, [], Callable(), func(): return phase < 0)

func label(parent: Node, text: String, size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", Color("c8dae4"))
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 38
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func selected_device() -> int:
	return remote_select.get_selected_id()

func refresh_remotes() -> void:
	var previous := selected_device()
	var known: Array = wii.states.keys()
	known.sort()
	var listed: Array = []
	for i in range(remote_select.item_count): listed.append(remote_select.get_item_id(i))
	if (listed == known and not known.is_empty()) or (known.is_empty() and listed == [-10]): return
	remote_select.clear()
	for device in known:
		remote_select.add_item(wii.device_name(device), device)
		if device == previous: remote_select.select(remote_select.item_count - 1)
	if known.is_empty(): remote_select.add_item("No Wii Remotes detected yet", -10)

func _process(_delta: float) -> void:
	get_meta("column").visible = phase < 0
	status_label.text = wii.status
	var state: Dictionary = wii.states.get(selected_device(), {})
	if phase >= 0 and not wii.eligible(state):
		phase = -1
		message = "Remote disconnected. Reconnect it before calibrating."
	wii.cursor_layer.visible = phase < 0
	calibrate_button.disabled = not wii.eligible(state)
	center_button.disabled = calibrate_button.disabled
	if state.is_empty():
		detail_label.text = message if not message.is_empty() else "Waiting for your remotes. The bridge window shows connection errors and setup progress."
	else:
		var tracked := wii.pointer(selected_device()) != null
		var saved: bool = wii.calibration.get(state.id, {}).has("top_left")
		detail_label.text = "Remote %d: %s\nNunchuk: %s   •   Sensor bar: %s   •   Pointer calibration: %s\n%s" % [selected_device() - wii.FIRST_DEVICE + 1, str(state.get("status", "")), "ready" if state.nunchuk else "not detected", "tracking" if tracked else "not visible", "saved" if saved else "needed", message]
	get_meta("test_area").queue_redraw()
	queue_redraw()

func begin_calibration() -> void:
	if not wii.eligible(wii.states.get(selected_device(), {})): return
	phase = 0
	message = "Hold the remote upright. Aim at the target and press A. Esc cancels."
	queue_redraw()

func capture_corner() -> void:
	var state: Dictionary = wii.states.get(selected_device(), {})
	if not wii.eligible(state) or state.get("ir") == null:
		message = "Sensor bar not visible. Power it and keep both ends in view, then press A again."
		return
	var raw := Vector2(state.ir[0], state.ir[1])
	if phase == 0:
		first_corner = raw
		phase = 1
	else:
		if wii.save_corners(selected_device(), first_corner, raw):
			phase = -1
			message = "Calibration saved for this remote. Move the pointer around to check it, then calibrate the next remote."
		else:
			phase = 0
			message = "The two aim positions were too close or could not be saved. Try again from the first target."

func draw_test(canvas: Control) -> void:
	var device := selected_device()
	var state: Dictionary = wii.states.get(device, {})
	var center := Vector2(70, 48)
	canvas.draw_circle(center, 38, Color("233e50"))
	canvas.draw_arc(center, 38, 0, TAU, 32, Color("7996a5"), 2, true)
	canvas.draw_circle(center + Vector2(wii.axis(device, JOY_AXIS_LEFT_X), wii.axis(device, JOY_AXIS_LEFT_Y)) * 30, 9, Color("ffd575"))
	var names := ["A", "B / FIRE", "Z / MINE", "C / REPAIR", "PLUS"]
	var codes := [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_START]
	for i in range(names.size()):
		var at := Vector2(150 + i * 160, 22)
		var color := Color("51edcf") if wii.button(device, codes[i]) else Color("637b88")
		canvas.draw_rect(Rect2(at, Vector2(144, 50)), Color(color, 0.15))
		canvas.draw_rect(Rect2(at, Vector2(144, 50)), color, false, 1)
		canvas.draw_string(ThemeDB.fallback_font, at + Vector2(12, 31), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
	if not state.is_empty() and state.get("ir") != null:
		canvas.draw_string(ThemeDB.fallback_font, Vector2(150, 96), "Sensor bar tracked — move the remote to test the pointer.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8296a5"))

func _draw() -> void:
	if phase < 0: return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.04, 0.06, 0.96))
	var target := get_viewport_rect().size * (Vector2(0.15, 0.15) if phase == 0 else Vector2(0.85, 0.85))
	draw_arc(target, 26, 0, TAU, 40, Color("ffd575"), 3, true)
	draw_line(target - Vector2(40, 0), target + Vector2(40, 0), Color.WHITE, 2)
	draw_line(target - Vector2(0, 40), target + Vector2(0, 40), Color.WHITE, 2)
	draw_string(ThemeDB.fallback_font, Vector2(220, 350), "REMOTE %d — AIM AT THE %s TARGET; PRESS A" % [selected_device() - wii.FIRST_DEVICE + 1, "TOP LEFT" if phase == 0 else "BOTTOM RIGHT"], HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(220, 395), message, HORIZONTAL_ALIGNMENT_LEFT, 880, 17, Color("b3cad7"))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if phase >= 0: phase = -1; message = "Calibration cancelled."
		else: back()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		if event.pressed and event.device == selected_device() and phase >= 0:
			if event.button_index == JOY_BUTTON_A: capture_corner()
			elif event.button_index in [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_START]:
				phase = -1
				message = "Calibration cancelled."
		get_viewport().set_input_as_handled()

func open_pairing() -> void:
	var path := OS.get_environment("HOME").path_join("Applications/WiimotePair.app")
	if OS.get_name() == "macOS" and DirAccess.dir_exists_absolute(path):
		OS.shell_open(path)
	else: message = "Pairing utility not installed. Run tools/wii/build_pairing.command first."

func back() -> void:
	if closed.get_connections().is_empty(): get_tree().change_scene_to_file("res://scenes/game/MainMenu.tscn")
	else: closed.emit()

func _exit_tree() -> void:
	if is_instance_valid(wii) and is_instance_valid(wii.cursor_layer): wii.cursor_layer.visible = true
