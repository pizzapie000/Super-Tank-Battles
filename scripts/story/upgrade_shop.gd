extends Control

signal closed
const Parts = preload("res://scripts/story/upgrade_parts.gd")
const Controls = preload("res://scripts/input/controller_input.gd")
var adventure: Node2D
var selected_player := 0
var heading: Label
var detail: Label
var improve: Button
var purchases: Array[Button] = []
var tabs: Array[Button] = []
var message: Label
var axis_direction := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(155, 30)
	panel.size = Vector2(970, 740)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172631")
	style.border_color = Color("7cf4bc")
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	heading = label(column, "", 27)
	label(column, "THE VILLAGE WORKSHOP · Thank you for sparing our homes.", 16)
	var row := HBoxContainer.new()
	column.add_child(row)
	for i in range(adventure.players.size()):
		var tab := button(row, "PLAYER %d" % (i + 1), func(): selected_player = i; refresh())
		tab.add_theme_color_override("font_color", DuelTank.readable_tint(StorySession.COLORS[i]))
		tabs.append(tab)
	detail = label(column, "", 18)
	improve = button(column, "", improve_current)
	label(column, "OR SWITCH YOUR POWERUP · New choices start at level I. One slot per tank.", 15)
	for part in Parts.TYPES.slice(1):
		var choice := HBoxContainer.new()
		column.add_child(choice)
		var description := label(choice, "%s — %s" % [part.to_upper(), Parts.DESCRIPTIONS[part]], 15)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.add_theme_color_override("font_color", Parts.COLORS[part])
		var buy := button(choice, "SWITCH · 3 SUPPLIES", choose_part.bind(part))
		buy.custom_minimum_size.x = 230
		purchases.append(buy)
	message = label(column, "Choose whose tank to tune. Supplies are shared by the crew.", 15)
	button(column, "BACK TO THE ROAD", func(): closed.emit()).grab_focus()
	preload("res://scripts/input/wii_menu.gd").attach(self, func(): closed.emit(), StorySession.devices)
	refresh()

func label(parent: Node, text: String, size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result

func button(parent: Node, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 43
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func refresh() -> void:
	var crew = adventure.players[selected_player]
	heading.text = "UPGRADE SHOP / %d SUPPLIES" % adventure.supplies
	detail.text = "P%d · %s" % [selected_player + 1, "STANDARD TANK" if crew.equipped_part.is_empty() else "%s · LEVEL %d / %d" % [crew.equipped_part.to_upper(), crew.part_level, Parts.MAX_LEVEL]]
	detail.text += "\n" + Parts.detail(crew.equipped_part, crew.part_level)
	var cost: int = maxi(1, crew.part_level) * 2
	improve.text = "UPGRADE TO LEVEL %d · %d SUPPLIES" % [crew.part_level + 1, cost] if crew.part_level < Parts.MAX_LEVEL else "MAXIMUM LEVEL REACHED"
	improve.disabled = crew.equipped_part.is_empty() or crew.part_level >= Parts.MAX_LEVEL or adventure.supplies < cost
	for i in range(purchases.size()): purchases[i].disabled = adventure.supplies < 3 or crew.equipped_part == Parts.TYPES[i + 1]
	for i in range(tabs.size()): tabs[i].text = ("● " if i == selected_player else "") + "PLAYER %d" % (i + 1)

func improve_current() -> void:
	message.text = adventure.shop_purchase(selected_player, "", true)
	refresh()

func choose_part(part: String) -> void:
	message.text = adventure.shop_purchase(selected_player, part, false)
	refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and StorySession.devices.has(event.device):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event is InputEventJoypadButton and not Controls.is_wii(event.device) and StorySession.devices.has(event.device) and event.pressed:
		if event.button_index == JOY_BUTTON_B: closed.emit()
		elif event.button_index == JOY_BUTTON_A:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and is_ancestor_of(focused) and not focused.disabled: focused.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and not Controls.is_wii(event.device) and StorySession.devices.has(event.device) and event.axis == JOY_AXIS_LEFT_Y:
		var direction := int(signf(event.axis_value)) if absf(event.axis_value) > 0.6 else 0
		if direction != 0 and direction != axis_direction: get_node("WiiMenu").move_focus(Vector2(0, direction))
		axis_direction = direction
		get_viewport().set_input_as_handled()
