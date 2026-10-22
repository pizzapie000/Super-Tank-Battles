extends RefCounted
## One input interface for ordinary gamepads and the local Wii bridge.

static func connected_devices() -> Array[int]:
	var result := Input.get_connected_joypads()
	result.append_array(bridge().connected_devices())
	return result

static func is_wii(device: int) -> bool:
	return device >= 1000 and device < 1000 + 4

static func device_name(device: int) -> String:
	return bridge().device_name(device) if is_wii(device) else Input.get_joy_name(device)

static func axis(device: int, code: int) -> float:
	return bridge().axis(device, code) if is_wii(device) else Input.get_joy_axis(device, code)

static func button(device: int, code: int) -> bool:
	return bridge().button(device, code) if is_wii(device) else Input.is_joy_button_pressed(device, code)

static func mine_button(device: int) -> int:
	return JOY_BUTTON_A if is_wii(device) else JOY_BUTTON_B

static func interact_button(device: int) -> int:
	return JOY_BUTTON_B if is_wii(device) else JOY_BUTTON_A

static func movement(device: int) -> Vector2:
	if is_wii(device):
		var left := button(device, JOY_BUTTON_DPAD_LEFT)
		var right := button(device, JOY_BUTTON_DPAD_RIGHT)
		var up := button(device, JOY_BUTTON_DPAD_UP)
		var down := button(device, JOY_BUTTON_DPAD_DOWN)
		if left or right or up or down:
			return Vector2(int(right) - int(left), int(down) - int(up)).normalized()
	return StorySession.stick(Vector2(axis(device, JOY_AXIS_LEFT_X), axis(device, JOY_AXIS_LEFT_Y)))

static func connect_changes(receiver: Callable) -> void:
	if not Input.joy_connection_changed.is_connected(receiver):
		Input.joy_connection_changed.connect(receiver)
	if not bridge().connection_changed.is_connected(receiver):
		bridge().connection_changed.connect(receiver)

static func rumble(device: int, weak: float, strong: float, duration: float) -> void:
	if not is_wii(device): Input.start_joy_vibration(device, weak, strong, duration)

static func aim(device: int, tank: Node2D) -> Variant:
	if is_wii(device):
		return bridge().world_aim(device, tank)
	var stick := StorySession.stick(Vector2(axis(device, JOY_AXIS_RIGHT_X), axis(device, JOY_AXIS_RIGHT_Y)))
	return null if stick.is_zero_approx() else tank.global_position + stick * 300

static func bridge() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("WiiInput")
