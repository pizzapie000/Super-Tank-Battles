extends Control

const ControllerInput = preload("res://scripts/input/controller_input.gd")

const Session = preload("res://scripts/pvp/duel_session.gd")
var mode: int = 0
var selectors: Array[OptionButton] = []
var mode_buttons: Array[Button] = []
var player_labels: Array[Label] = []
var descriptions: Array[Label] = []
var status: Label
var start_button: Button
var starting: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101923")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var column := VBoxContainer.new()
	column.position = Vector2(175, 35)
	column.size = Vector2(930, 730)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	label(column, "TWO PLAYER DUEL", 34, Color("edf4f7"))
	label(column, "Playing with controllers? Choose your setup before the battle.", 21, Color("b3c8d2"))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	column.add_child(modes)
	for i in range(3):
		var node := button(modes, ["SHARED KEYBOARD", "KEYBOARD + CONTROLLER", "TWO CONTROLLERS"][i], choose_mode.bind(i))
		node.toggle_mode = true
		node.add_theme_font_size_override("font_size", 15)
		mode_buttons.append(node)
	label(column, "Connect controllers now, or press A / Cross on one to join.", 16, Color("8296a5"))
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 22)
	column.add_child(pair)
	for i in range(2):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172631")
		style.border_color = DuelTank.readable_tint(DuelTank.PLAYER_COLORS[i])
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 18
		style.content_margin_bottom = 18
		panel.add_theme_stylebox_override("panel", style)
		pair.add_child(panel)
		var contents := VBoxContainer.new()
		contents.add_theme_constant_override("separation", 12)
		panel.add_child(contents)
		label(contents, "P%d  /  %s" % [i + 1, "ROYAL BLUE" if i == 0 else "ORANGE"], 23, style.border_color)
		player_labels.append(label(contents, "", 18, Color("edf4f7")))
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = 42
		selector.fit_to_longest_item = false
		selector.clip_text = true
		selector.item_selected.connect(func(_index: int): refresh_status())
		contents.add_child(selector)
		selectors.append(selector)
		var description := label(contents, "", 16, Color("b3c8d2"))
		description.custom_minimum_size = Vector2(0, 85)
		descriptions.append(description)
	status = label(column, "", 17, Color("ffdc81"))
	start_button = button(column, "START DUEL", start_duel)
	button(column, "BACK TO MODES", back)
	label(column, "First to seven points. One hit ends the round.\nWeapon crates appear 5 seconds after GO — drive over one to equip it.\nGatling: 36 rounds  •  Shotgun: 5 blasts  •  Heat seeker: 3 missiles", 16, Color("8296a5"))
	ControllerInput.connect_changes(connection_changed)
	if Session.devices[0] >= 0:
		mode = 2
	elif Session.devices[0] == Session.KEYBOARD:
		mode = 1
	refresh(Session.devices)
	mode_buttons[mode].grab_focus()
	var wii_button := button(self, "WII REMOTE SETUP", show_wii_setup)
	wii_button.position = Vector2(875, 35)
	wii_button.size = Vector2(230, 38)
	wii_button.custom_minimum_size.y = 38
	preload("res://scripts/input/wii_menu.gd").attach(self, back, [], func(device: int): return not selected_pair().has(device), func(): return not starting)

func label(parent: Node, value: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

func button(parent: Node, value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size.y = 46
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("172631")
	normal.border_color = Color("38505e")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	node.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("243e4e")
	node.add_theme_stylebox_override("hover", hover)
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color("31546a")
	selected.border_color = Color("c7e9f7")
	selected.set_border_width_all(2)
	node.add_theme_stylebox_override("pressed", selected)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func selected_pair() -> Array[int]:
	if mode == 0:
		return [Session.SHARED_LEFT, Session.SHARED_RIGHT]
	var pair: Array[int] = []
	for i in range(2):
		pair.append(Session.KEYBOARD if mode == 1 and i == 0 else selectors[i].get_selected_id())
	return pair

func choose_mode(value: int) -> void:
	var previous := selected_pair()
	mode = value
	refresh(previous)
	mode_buttons[mode].grab_focus()

func refresh(previous: Array[int] = []) -> void:
	var connected := connected_devices()
	for i in range(3):
		mode_buttons[i].set_pressed_no_signal(i == mode)
	for i in range(2):
		var uses_controller := mode == 2 or (mode == 1 and i == 1)
		selectors[i].clear()
		selectors[i].visible = uses_controller
		if uses_controller:
			for device in connected:
				selectors[i].add_item("%s  [%d]" % [Session.controller_name(device), device + 1], device)
			if connected.is_empty():
				selectors[i].add_item("Connect a controller…", -10)
			var preferred: int = previous[i] if previous.size() == 2 else -10
			if not connected.has(preferred) and not connected.is_empty():
				preferred = connected[mini(i if mode == 2 else 0, connected.size() - 1)]
			for index in range(selectors[i].item_count):
				if selectors[i].get_item_id(index) == preferred:
					selectors[i].select(index)
			player_labels[i].text = "Controller"
			descriptions[i].text = "Left stick: move\nRight stick: aim\nRT / R2 or RB / R1: fire\nStart / Options: pause"
		else:
			player_labels[i].text = "Keyboard + mouse" if mode == 1 else "Shared keyboard"
			descriptions[i].text = "WASD / arrows: move\nMouse: aim\nClick / Space: fire\nEsc: pause" if mode == 1 else ("E / D: forward / reverse\nS / F: turn\nQ: fire\nEsc: pause" if i == 0 else "Up / Down: forward / reverse\nLeft / Right: turn\nM: fire\nEsc: pause")
	refresh_status()
	update_wii_hints()

func update_wii_hints() -> void:
	var pair := selected_pair()
	for i in range(2):
		if ControllerInput.is_wii(pair[i]):
			player_labels[i].text = "Wii Remote + Nunchuk"
			descriptions[i].text = "Nunchuk stick: move\nPoint at screen: aim\nB: fire\nPlus: pause"

func refresh_status() -> void:
	var pair := selected_pair()
	var valid := Session.valid_pair(pair, connected_devices())
	start_button.disabled = not valid
	if valid:
		status.text = "Both players ready. Select Start Duel, or press Start / Options."
	elif mode == 2 and pair[0] == pair[1] and pair[0] >= 0:
		status.text = "Each player needs a different controller."
	else:
		status.text = "Connect %s to begin." % ("two controllers" if mode == 2 else "a controller")
	update_wii_hints()

func show_wii_setup() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var setup = preload("res://scenes/game/WiiSetup.tscn").instantiate()
	setup.closed.connect(func():
		setup.queue_free()
		refresh(selected_pair())
		if is_instance_valid(previous_focus): previous_focus.grab_focus()
	)
	add_child(setup)

func join_controller(device: int) -> void:
	var pair := selected_pair()
	if pair.has(device):
		return
	if mode == 0:
		mode = 1
		pair.assign([Session.KEYBOARD, device])
	elif mode == 1:
		mode = 2
		pair.assign([pair[1], device])
	elif not connected_devices().has(pair[0]):
		pair[0] = device
	elif not connected_devices().has(pair[1]):
		pair[1] = device
	refresh(pair)
	if not start_button.disabled:
		start_button.grab_focus()

func connection_changed(_device: int, _connected: bool) -> void:
	refresh(selected_pair())

func _input(event: InputEvent) -> void:
	if starting:
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A and not selected_pair().has(event.device):
			join_controller(event.device)
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_START:
			start_duel()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_B:
			back()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()

func start_duel() -> void:
	var pair := selected_pair()
	if starting or not Session.valid_pair(pair, connected_devices()):
		return
	starting = true
	Session.devices.assign(pair)
	get_tree().change_scene_to_file("res://scenes/game/DuelArena.tscn")

func connected_devices() -> Array[int]:
	return ControllerInput.connected_devices()

func back() -> void:
	if not starting:
		get_tree().change_scene_to_file("res://scenes/game/MainMenu.tscn")
