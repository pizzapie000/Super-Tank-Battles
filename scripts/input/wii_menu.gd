extends Node
## Menu-only Wii controls. Gameplay keeps its own aim, fire and join handling.

const Controls = preload("res://scripts/input/controller_input.gd")

class PopupInput extends Node:
	var menu: Node
	func _input(event: InputEvent) -> void:
		menu.handle_input(event, get_viewport())

var scope: Control
var back_action: Callable
var allowed_devices: Array[int] = []
var join_first: Callable
var enabled: Callable
var pointers: Dictionary = {}
var pointer_mode: Dictionary = {}
var pointer_resume_at: Dictionary = {}
var directions: Dictionary = {}
var repeat_at: Dictionary = {}
var option: OptionButton

static func attach(root: Control, back: Callable = Callable(), allowed: Array[int] = [], join: Callable = Callable(), available: Callable = Callable()) -> Node:
	var menu = load("res://scripts/input/wii_menu.gd").new()
	menu.scope = root
	menu.back_action = back
	menu.allowed_devices = allowed
	menu.join_first = join
	menu.enabled = available
	root.add_child(menu)
	return menu

func _ready() -> void:
	name = "WiiMenu"
	add_to_group("wii_menus")

func active() -> bool:
	if not scope.is_visible_in_tree() or (enabled.is_valid() and not enabled.call()): return false
	for menu in get_tree().get_nodes_in_group("wii_menus"):
		if menu != self and scope.is_ancestor_of(menu.scope) and menu.scope.is_visible_in_tree(): return false
	return true

func permitted(device: int) -> bool:
	return Controls.is_wii(device) and (allowed_devices.is_empty() or allowed_devices.has(device))

func buttons() -> Array[BaseButton]:
	var result: Array[BaseButton] = []
	for node in scope.find_children("*", "BaseButton", true, false):
		if node.is_visible_in_tree() and not node.disabled and node.focus_mode != Control.FOCUS_NONE:
			result.append(node)
	return result

func hit_button(point: Vector2) -> BaseButton:
	var candidates := buttons()
	candidates.reverse()
	for node in candidates:
		var local: Vector2 = node.get_global_transform_with_canvas().affine_inverse() * point
		if not Rect2(Vector2.ZERO, node.size).has_point(local): continue
		var visible := true
		var parent := node.get_parent()
		while parent is Control:
			if parent.clip_contents:
				var clipped: Vector2 = parent.get_global_transform_with_canvas().affine_inverse() * point
				if not Rect2(Vector2.ZERO, parent.size).has_point(clipped): visible = false
			parent = parent.get_parent()
		if visible: return node
	return null

func _process(_delta: float) -> void:
	if not active(): return
	var wii := Controls.bridge()
	for device in wii.connected_devices():
		if not permitted(device): continue
		var point = wii.pointer(device)
		if point != null and not popup_open():
			point *= get_viewport().get_visible_rect().size
			if not pointers.has(device) or point.distance_to(pointers[device]) > 9:
				pointers[device] = point
				if wii.seconds() >= pointer_resume_at.get(device, 0):
					pointer_mode[device] = true
					var hovered := hit_button(point)
					if hovered != null: hovered.grab_focus()
		var direction := navigation_direction(device)
		var previous: Vector2 = directions.get(device, Vector2.ZERO)
		if direction != Vector2.ZERO: pointer_resume_at[device] = wii.seconds() + 0.8
		if direction != Vector2.ZERO and (direction != previous or wii.seconds() >= repeat_at.get(device, 0)):
			pointer_mode[device] = false
			move_focus(direction)
			repeat_at[device] = wii.seconds() + (0.38 if direction != previous else 0.16)
		directions[device] = direction

func navigation_direction(device: int) -> Vector2:
	var x := Controls.axis(device, JOY_AXIS_LEFT_X)
	var y := Controls.axis(device, JOY_AXIS_LEFT_Y)
	for item in [[JOY_BUTTON_DPAD_LEFT, Vector2.LEFT], [JOY_BUTTON_DPAD_RIGHT, Vector2.RIGHT], [JOY_BUTTON_DPAD_UP, Vector2.UP], [JOY_BUTTON_DPAD_DOWN, Vector2.DOWN]]:
		if Controls.button(device, item[0]): return item[1]
	if maxf(absf(x), absf(y)) < 0.6: return Vector2.ZERO
	return Vector2(signf(x), 0) if absf(x) > absf(y) else Vector2(0, signf(y))

func popup_open() -> bool:
	return is_instance_valid(option) and option.get_popup().visible

func move_focus(direction: Vector2) -> void:
	if popup_open():
		var popup := option.get_popup()
		var index := popup.get_focused_item()
		for _attempt in range(option.item_count):
			index = posmod(index + (1 if direction.x + direction.y > 0 else -1), option.item_count)
			if not option.is_item_disabled(index) and not option.is_item_separator(index):
				popup.set_focused_item(index)
				return
		return
	var candidates := buttons()
	if candidates.is_empty(): return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not candidates.has(focused):
		candidates[0].grab_focus()
		return
	var side := SIDE_LEFT if direction.x < 0 else (SIDE_RIGHT if direction.x > 0 else (SIDE_TOP if direction.y < 0 else SIDE_BOTTOM))
	var neighbor := focused.find_valid_focus_neighbor(side)
	if neighbor != null and candidates.has(neighbor): neighbor.grab_focus()
	else: candidates[posmod(candidates.find(focused) + (1 if direction.x + direction.y > 0 else -1), candidates.size())].grab_focus()
	var target := get_viewport().gui_get_focus_owner()
	var parent := target.get_parent()
	while parent != null and parent != scope:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent = parent.get_parent()

func activate(device: int) -> void:
	if popup_open():
		var selected := option.get_popup().get_focused_item()
		var selected_option := option
		selected_option.get_popup().hide()
		if selected >= 0 and not selected_option.is_item_disabled(selected) and not selected_option.is_item_separator(selected):
			selected_option.select(selected)
			selected_option.item_selected.emit(selected)
		return
	var target: BaseButton
	var point = Controls.bridge().pointer(device)
	if point != null and pointer_mode.get(device, true):
		target = hit_button(point * get_viewport().get_visible_rect().size)
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton and buttons().has(focused): target = focused
	if target == null: return
	target.grab_focus()
	if target is OptionButton:
		option = target
		if not option.get_popup().has_node("WiiPopupInput"):
			var relay := PopupInput.new()
			relay.name = "WiiPopupInput"
			relay.menu = self
			option.get_popup().add_child(relay)
		option.show_popup()
		option.get_popup().set_focused_item(option.selected)
	else:
		if target.toggle_mode: target.button_pressed = not target.button_pressed
		target.pressed.emit()

func _input(event: InputEvent) -> void:
	handle_input(event, get_viewport())

func handle_input(event: InputEvent, viewport: Viewport) -> void:
	if not active() or not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or not permitted(event.device): return
	if event is InputEventJoypadMotion:
		viewport.set_input_as_handled()
		return
	if event.button_index == JOY_BUTTON_A and event.pressed:
		if join_first.is_valid() and join_first.call(event.device): return
		viewport.set_input_as_handled()
		activate(event.device)
	elif event.button_index in [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER] and event.pressed:
		viewport.set_input_as_handled()
		if popup_open(): option.get_popup().hide()
		elif back_action.is_valid(): back_action.call()
	elif event.button_index == JOY_BUTTON_START:
		if popup_open():
			option.get_popup().hide()
			viewport.set_input_as_handled()
		return # Lobbies and pause screens keep their Plus shortcut.
	else:
		# No default GUI repeat or A-release may activate a second screen.
		viewport.set_input_as_handled()
